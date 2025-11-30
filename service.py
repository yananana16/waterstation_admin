import math
import time
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
from sklearn.cluster import DBSCAN
import folium
from collections import defaultdict
import argparse
from datetime import datetime, timedelta, date
from sklearn.linear_model import LinearRegression
import calendar

import matplotlib
matplotlib.use("Agg")  # headless backend for servers (Render / Linux)
import matplotlib.pyplot as plt

LITERS_PER_REFILL = 25  # 1 container = 25L
LITERS_PER_M3 = 1000.0  # 1 cubic meter = 1000 liters

# -------------------------------
# Debug helper
# -------------------------------
def log_step(msg: str):
    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{now}] {msg}", flush=True)

# -------------------------------
# Initialize Firebase Admin SDK
# -------------------------------
def init_firestore():
    log_step("Initializing Firestore client...")
    cred = credentials.Certificate('ai-model/serviceaccount.json')
    try:
        app = firebase_admin.get_app()
        log_step("Reusing existing Firebase app.")
    except ValueError:
        app = firebase_admin.initialize_app(cred)
        log_step("Created new Firebase app.")
    return firestore.client(app)

# -------------------------------
# Helper: classify district trend
# -------------------------------
def classify_trend(total_m3: float, forecast_12m_m3: float) -> str:
    """
    Classify district trend based on ratio of forecasted demand vs historical demand.

    ratio = forecast_12m_m3 / total_m3

    - ratio >= 1.2       → Increasing
    - 0.8 <= ratio <1.2  → Stable
    - ratio < 0.8        → Decreasing
    - total_m3 <= 0      → Unknown
    """
    if total_m3 <= 0:
        return "Unknown"

    ratio = forecast_12m_m3 / total_m3
    if ratio >= 1.2:
        return "Increasing"
    elif ratio <= 0.8:
        return "Decreasing"
    else:
        return "Stable"

# -------------------------------
# Save district recommendations (already ranked & with trend)
# -------------------------------
def save_recommendations(db, recommendations):
    log_step("Saving district recommendations to Firestore...")
    recs_ref = db.collection("station_recommendations")
    for rec in recommendations:
        rec['createdAt'] = datetime.utcnow()
        doc_id = rec['district'].replace(" ", "_")
        recs_ref.document(doc_id).set(rec)
    log_step(f"Saved {len(recommendations)} district recommendations (overwrite mode).")

# -------------------------------
# Save overall summary doc (with monthly trend)
# -------------------------------
def save_overall_summary(db, recommendations, monthly_trend_current_year):
    if not recommendations:
        log_step("No recommendations to summarize for Overall.")
        return

    log_step("Computing and saving Overall summary document...")
    overall_total_m3 = sum(r['district_total_m3'] for r in recommendations)
    overall_next_month_m3 = sum(r['district_forecast_next_month_m3'] for r in recommendations)
    overall_12m_m3 = sum(r['district_forecast_12m_m3'] for r in recommendations)

    # Highest / lowest by next month demand
    sorted_by_next_month = sorted(
        recommendations,
        key=lambda r: r['district_forecast_next_month_m3'],
        reverse=True
    )
    highest_district = sorted_by_next_month[0]['district']
    lowest_district = sorted_by_next_month[-1]['district']

    overall_doc = {
        "overall_total_m3": overall_total_m3,
        "overall_forecast_next_month_m3": overall_next_month_m3,
        "overall_forecast_12m_m3": overall_12m_m3,
        "highest_next_month_district": highest_district,
        "lowest_next_month_district": lowest_district,
        "monthly_trend_current_year": monthly_trend_current_year,
        "createdAt": datetime.utcnow(),
    }

    recs_ref = db.collection("station_recommendations")
    recs_ref.document("Overall").set(overall_doc)
    log_step("Saved Overall district summary document.")

# -------------------------------
# Fetch station + monthly demand
# -------------------------------
def fetch_data_firestore(db):
    """
    Fetch station metadata and compute demand in LITERS (not sales).

    Demand is computed only from:
      - orders where status == 'Completed'
      - items inside each order whose name contains 'refill'

    Each such item contributes: item.quantity * 25L.

    We build:
      station_monthly_liters[station_id][month_start] = liters
      overall_monthly_liters[month_start] = liters

    For each station, we then create:
      - forecast_next_month_liters
      - forecast_12m_liters
      - monthly_forecast_current_year[month] (for trend line)
    """
    start_total = time.time()

    stations_ref = db.collection('station_owners')
    stations_data = []

    log_step('Starting Firestore query for Completed orders...')
    orders_ref = db.collection('orders').where('status', '==', 'Completed')

    # Per-station monthly demand (liters)
    station_monthly_liters = defaultdict(lambda: defaultdict(float))
    # Overall monthly demand (liters) for graph (all years)
    overall_monthly_liters = defaultdict(float)

    order_count = 0
    loop_start = time.time()
    for order in orders_ref.stream():
        order_count += 1
        if order_count % 200 == 0:
            log_step(f"Processed {order_count} orders so far...")

        order_dict = order.to_dict()

        # Double-check status, just in case
        if order_dict.get('status') != "Completed":
            continue

        # Count ONLY refill water items in this order
        refill_units = 0
        items = order_dict.get('items', [])

        for item in items:
            item_name = str(item.get('name', '')).lower()
            item_quantity = item.get('quantity', 0)

            # Only include items that are water refills
            if "refill" in item_name:
                try:
                    refill_units += float(item_quantity)
                except (ValueError, TypeError):
                    pass

        # No refill water in this order → ignore
        if refill_units <= 0:
            continue

        # Convert refills to liters
        liters = refill_units * LITERS_PER_REFILL

        # Get order date
        created_at = order_dict.get('createdAt') or order_dict.get('created_at')
        order_date = None
        if isinstance(created_at, datetime):
            order_date = created_at.date()
        elif hasattr(created_at, 'to_datetime'):
            order_date = created_at.to_datetime().date()
        elif isinstance(created_at, str):
            try:
                order_date = datetime.fromisoformat(created_at).date()
            except ValueError:
                pass

        if order_date is None:
            continue

        # Normalize to "month start" (e.g. 2025-11-01)
        month_start = order_date.replace(day=1)

        # Some orders may have stationOwnerIds (array) or stationOwnerId (string)
        station_ids = order_dict.get('stationOwnerIds') or order_dict.get('stationOwnerId') or []
        if isinstance(station_ids, str):
            station_ids = [station_ids]

        for sid in station_ids:
            station_monthly_liters[sid][month_start] += liters
            overall_monthly_liters[month_start] += liters

    log_step(f"Finished streaming orders. Total orders seen: {order_count}. "
             f"Loop time: {time.time() - loop_start:.2f}s")

    # -------------------------------
    # Forecast next month & 12 months per station (in liters)
    # + monthly forecast for current year
    # -------------------------------
    log_step("Starting per-station regression & forecasting...")
    station_forecast_next_month_liters = {}
    station_forecast_12m_liters = {}
    station_monthly_forecast_current_year = defaultdict(dict)

    current_year = datetime.utcnow().year
    current_year_months = [date(current_year, m, 1) for m in range(1, 13)]

    station_counter = 0
    for station_id, monthly_series in station_monthly_liters.items():
        station_counter += 1
        if station_counter % 100 == 0:
            log_step(f"Processed regression for {station_counter} stations...")

        if not monthly_series:
            station_forecast_next_month_liters[station_id] = 0.0
            station_forecast_12m_liters[station_id] = 0.0
            for m in current_year_months:
                station_monthly_forecast_current_year[station_id][m] = 0.0
            continue

        months_sorted = sorted(monthly_series.keys())
        base_month = months_sorted[0]

        # Feature: month index (0,1,2,…) relative to base month
        X = np.array(
            [(m.year - base_month.year) * 12 + (m.month - base_month.month)
             for m in months_sorted],
            dtype=float
        ).reshape(-1, 1)
        y = np.array([monthly_series[m] for m in months_sorted], dtype=float)

        if len(X) >= 3:
            model = LinearRegression()
            model.fit(X, y)

            last_index = (months_sorted[-1].year - base_month.year) * 12 + \
                         (months_sorted[-1].month - base_month.month)

            # === Next month forecast (liters) ===
            next_month_index = np.array([[last_index + 1]], dtype=float)
            forecast_next_month = float(model.predict(next_month_index)[0])
            forecast_next_month = max(0, forecast_next_month)

            # === 12-month total forecast (liters) ===
            future_indices = np.arange(last_index + 1, last_index + 13, dtype=float).reshape(-1, 1)
            preds = model.predict(future_indices)
            preds = np.clip(preds, 0, None)
            forecast_12m = float(preds.sum())

            # === Monthly forecast for current year (liters) ===
            for m in current_year_months:
                idx = (m.year - base_month.year) * 12 + (m.month - base_month.month)
                pred = float(model.predict(np.array([[idx]], dtype=float))[0])
                station_monthly_forecast_current_year[station_id][m] = max(0, pred)

        else:
            # Not enough history → use mean monthly demand
            mean_monthly = float(y.mean()) if len(y) > 0 else 0.0
            forecast_next_month = mean_monthly
            forecast_12m = mean_monthly * 12

            for m in current_year_months:
                station_monthly_forecast_current_year[station_id][m] = mean_monthly

        station_forecast_next_month_liters[station_id] = forecast_next_month
        station_forecast_12m_liters[station_id] = forecast_12m

    log_step(f"Finished regression/forecasting for {station_counter} stations.")

    # -------------------------------
    # Build stations_df (liters stored, m³ shown in UI)
    # -------------------------------
    log_step("Building stations_df from station_owners collection...")
    station_docs_count = 0
    for station in stations_ref.stream():
        station_docs_count += 1
        station_dict = station.to_dict()
        station_id = station.id
        district_id = station_dict.get('districtID')
        district_name = station_dict.get('districtName')
        lat = station_dict.get('location', {}).get('latitude')
        lng = station_dict.get('location', {}).get('longitude')
        water_type = station_dict.get('waterType')

        if pd.isna(lat) or pd.isna(lng):
            continue

        # Sum total historical liters for this station
        monthly_for_station = station_monthly_liters.get(station_id, {})
        total_liters_history = sum(monthly_for_station.values()) if monthly_for_station else 0.0

        forecast_next_month_liters = station_forecast_next_month_liters.get(station_id, 0.0)
        forecast_12m_liters = station_forecast_12m_liters.get(station_id, 0.0)

        stations_data.append({
            'station_id': station_id,
            'district_id': district_id,
            'district_name': district_name,
            'lat': lat,
            'lng': lng,
            'water_type': water_type,
            'total_liters_history': total_liters_history,
            'forecast_next_month_liters': forecast_next_month_liters,
            'forecast_12m_liters': forecast_12m_liters
        })

    log_step(f"Fetched {station_docs_count} station_owners docs; "
             f"{len(stations_data)} used with valid coordinates.")
    stations_df = pd.DataFrame(stations_data)

    # -------------------------------
    # Build district & overall monthly actual + forecast (current year)
    # -------------------------------
    log_step("Aggregating district & overall monthly actual + forecast (current year)...")
    district_monthly_actual_liters = defaultdict(lambda: defaultdict(float))
    district_monthly_forecast_liters = defaultdict(lambda: defaultdict(float))
    overall_monthly_forecast_current_year_liters = defaultdict(float)

    # Map station → district
    station_to_district = {row['station_id']: row['district_name'] for row in stations_data}

    # Actual (only current year)
    for station_id, monthly_series in station_monthly_liters.items():
        district_name = station_to_district.get(station_id)
        if not district_name:
            continue
        for m, liters in monthly_series.items():
            if m.year == current_year:
                district_monthly_actual_liters[district_name][m] += liters

    # Forecast (current year months)
    for station_id, monthly_forecast in station_monthly_forecast_current_year.items():
        district_name = station_to_district.get(station_id)
        if not district_name:
            continue
        for m, liters in monthly_forecast.items():
            district_monthly_forecast_liters[district_name][m] += liters
            overall_monthly_forecast_current_year_liters[m] += liters

    log_step(f"Finished fetch_data_firestore in {time.time() - start_total:.2f}s.")
    return (
        stations_df,
        overall_monthly_liters,
        district_monthly_actual_liters,
        district_monthly_forecast_liters,
        overall_monthly_forecast_current_year_liters,
        current_year,
    )

# -------------------------------
# DBSCAN clustering + recommendation (district-level, saved in m³)
# -------------------------------
def dynamic_clustering(stations_df):
    locations = stations_df[['lat', 'lng']].values
    clustering = DBSCAN(eps=0.01, min_samples=2, metric='haversine').fit(np.radians(locations))
    stations_df.loc[:, 'cluster'] = clustering.labels_
    return stations_df

def recommend_best_location_for_district(stations_df, district_name, range_radius=50):
    log_step(f"Running DBSCAN & recommendation for district: {district_name}...")
    district_df = stations_df[stations_df['district_name'] == district_name].copy()
    if len(district_df) < 2:
        log_step(f"Not enough stations in {district_name} to perform clustering.")
        return None

    district_df = dynamic_clustering(district_df)

    # Demand signal (for clustering) = next month forecast; fallback to history if 0
    district_df['demand_signal'] = district_df.apply(
        lambda row: row['forecast_next_month_liters']
        if row['forecast_next_month_liters'] > 0
        else row['total_liters_history'],
        axis=1
    )

    # District-level totals in LITERS (all stations in the district)
    district_total_liters_history = float(district_df['total_liters_history'].sum())
    district_forecast_next_month_liters = float(district_df['forecast_next_month_liters'].sum())
    district_forecast_12m_liters = float(district_df['forecast_12m_liters'].sum())

    # Convert district totals to m³ for saving / display
    district_total_m3 = district_total_liters_history / LITERS_PER_M3
    district_forecast_next_month_m3 = district_forecast_next_month_liters / LITERS_PER_M3
    district_forecast_12m_m3 = district_forecast_12m_liters / LITERS_PER_M3

    # Trend classification
    district_trend = classify_trend(district_total_m3, district_forecast_12m_m3)

    # Cluster-level demand (for choosing best cluster)
    cluster_demand = district_df.groupby('cluster')['demand_signal'].sum()
    highest_demand_cluster = cluster_demand.idxmax()
    recommended_stations = district_df[district_df['cluster'] == highest_demand_cluster]

    weights = recommended_stations['demand_signal'].values
    weighted_lat = float(np.average(recommended_stations['lat'], weights=weights))
    weighted_lng = float(np.average(recommended_stations['lng'], weights=weights))

    explanation = (
        f"This recommendation for {district_name} is based on AI-driven water demand analytics. "
        f"The system measures refill demand in liters internally but converts it to cubic meters (m³) "
        f"for reporting, which is the standard unit used in water utilities. "
        f"For this district, the total historical demand across all stations is "
        f"about {district_total_m3:.2f} m³ of water. "
        f"The model forecasts approximately {district_forecast_next_month_m3:.2f} m³ "
        f"of demand for next month, and around {district_forecast_12m_m3:.2f} m³ "
        f"for the next 12 months. "
        f"Based on these values, the district's demand trend is classified as {district_trend}. "
        f"Using DBSCAN, we identify the area where this demand is most concentrated and compute "
        f"a weighted center point. This point and its surrounding {range_radius} meters represent "
        f"the area where water demand is strongest within the district."
    )

    return {
        'district': district_name,
        'lat': weighted_lat,
        'lng': weighted_lng,
        'range_radius': range_radius,
        'highest_demand_cluster': int(highest_demand_cluster),

        # District-wide demand (stored in m³)
        'district_total_m3': district_total_m3,
        'district_forecast_next_month_m3': district_forecast_next_month_m3,
        'district_forecast_12m_m3': district_forecast_12m_m3,

        # Trend label
        'district_trend': district_trend,

        'explanation': explanation
    }

# -------------------------------
# Plot overall monthly demand (for Federated view, in m³)
# -------------------------------
def plot_overall_monthly_demand(overall_monthly_liters):
    """
    Creates a PNG graph: overall_monthly_demand.png
    - X-axis: months (YYYY-MM)
    - Y-axis: total m³ per month (converted from liters)
    """
    log_step("Generating overall_monthly_demand.png...")
    if not overall_monthly_liters:
        log_step("No monthly demand data available for plotting.")
        return

    months_sorted = sorted(overall_monthly_liters.keys())
    # Convert liters → m³ for plotting
    values_m3 = [overall_monthly_liters[m] / LITERS_PER_M3 for m in months_sorted]
    labels = [m.strftime("%Y-%m") for m in months_sorted]

    plt.figure(figsize=(10, 5))
    plt.plot(labels, values_m3, marker='o')
    plt.xticks(rotation=45, ha='right')
    plt.xlabel("Month")
    plt.ylabel("Total demand (m³)")
    plt.title("Overall Monthly Water Demand (All Stations) in m³")
    plt.tight_layout()
    plt.savefig("overall_monthly_demand.png")
    plt.close()
    log_step("Saved demand trend graph to overall_monthly_demand.png")

    # Print simple year comparison in m³ to help your explanation
    current_year = datetime.utcnow().year
    yearly_totals_m3 = defaultdict(float)
    for month, liters in overall_monthly_liters.items():
        yearly_totals_m3[month.year] += liters / LITERS_PER_M3

    for year, total_m3 in sorted(yearly_totals_m3.items()):
        log_step(f"Year {year}: total demand ≈ {total_m3:.2f} m³")

    if len(yearly_totals_m3) >= 2 and current_year in yearly_totals_m3:
        prev_year = current_year - 1
        if prev_year in yearly_totals_m3:
            log_step(
                f"Comparison: Year {prev_year} demand = {yearly_totals_m3[prev_year]:.2f} m³, "
                f"current year {current_year} demand = {yearly_totals_m3[current_year]:.2f} m³"
            )

# -------------------------------
# Visualization of stations + recommendations (map)
# -------------------------------
def visualize_stations(stations_df, recommendations):
    log_step("Generating Folium map for stations & recommendations...")
    map_center = [stations_df['lat'].mean(), stations_df['lng'].mean()]
    m = folium.Map(location=map_center, zoom_start=12)

    # Existing stations (show demand in m³ for readability)
    for _, row in stations_df.iterrows():
        total_m3 = row['total_liters_history'] / LITERS_PER_M3
        next_month_m3 = row['forecast_next_month_liters'] / LITERS_PER_M3
        forecast_12m_m3 = row['forecast_12m_liters'] / LITERS_PER_M3

        popup_html = (
            f"Station: {row['station_id']}<br>"
            f"District: {row['district_name']}<br>"
            f"Total Historical Demand: {total_m3:.2f} m³<br>"
            f"Forecast Next Month: {next_month_m3:.2f} m³<br>"
            f"Forecast Next 12 Months: {forecast_12m_m3:.2f} m³"
        )
        folium.Marker(
            location=[row['lat'], row['lng']],
            popup=popup_html,
            icon=folium.Icon(color='blue', icon='info-sign')
        ).add_to(m)

    # Recommended district areas
    for rec in recommendations:
        popup_html = (
            f"Recommended Area for {rec['district']}<br>"
            f"{rec['explanation']}"
        )
        folium.Marker(
            location=[rec['lat'], rec['lng']],
            popup=popup_html,
            icon=folium.Icon(color='red', icon='star')
        ).add_to(m)

    m.save("stations_recommendations_map.html")
    log_step("Map saved to stations_recommendations_map.html")

# -------------------------------
# Main
# -------------------------------
def main(mode="firestore", csv_path="synthetic_stations.csv"):
    log_step("===== AI Demand & Recommendation job started =====")
    job_start = time.time()

    db = init_firestore()

    if mode == "firestore":
        (
            stations_df,
            overall_monthly_liters,
            district_monthly_actual_liters,
            district_monthly_forecast_liters,
            overall_monthly_forecast_current_year_liters,
            current_year,
        ) = fetch_data_firestore(db)
    else:
        log_step("Running in CSV demo mode.")
        stations_df = pd.read_csv(csv_path)
        overall_monthly_liters = {}
        district_monthly_actual_liters = defaultdict(lambda: defaultdict(float))
        district_monthly_forecast_liters = defaultdict(lambda: defaultdict(float))
        overall_monthly_forecast_current_year_liters = defaultdict(float)
        current_year = datetime.utcnow().year

    current_year_months = [date(current_year, m, 1) for m in range(1, 13)]
    today = datetime.utcnow().date()
    first_day_current_month = date(current_year, today.month, 1)

    log_step("Starting per-district DBSCAN + recommendation...")
    recommendations = []
    for district_name in stations_df['district_name'].dropna().unique():
        rec = recommend_best_location_for_district(stations_df, district_name, range_radius=50)
        if rec:
            recommendations.append(rec)

    log_step(f"Finished generating raw recommendations for {len(recommendations)} districts.")

    if recommendations:
        # ----- Add monthly trend map for each district (Option B: hybrid for current month) -----
        log_step("Building monthly_trend_current_year for each district...")
        for rec in recommendations:
            district_name = rec['district']
            monthly_trend_map = {}
            for m in current_year_months:
                key = m.strftime("%Y-%m")

                if m < first_day_current_month:
                    # Past month → use actual only
                    actual_liters = district_monthly_actual_liters[district_name].get(m, 0.0)
                    forecast_liters = None
                    actual_m3 = actual_liters / LITERS_PER_M3
                    forecast_m3 = None

                elif m == first_day_current_month:
                    # Current month → hybrid: actual_so_far + forecast_remaining_days
                    actual_liters = district_monthly_actual_liters[district_name].get(m, 0.0)
                    full_forecast_liters = district_monthly_forecast_liters[district_name].get(m, 0.0)

                    # Days in this month
                    days_in_month = calendar.monthrange(m.year, m.month)[1]
                    days_elapsed = today.day
                    remaining_days = max(days_in_month - days_elapsed, 0)

                    # Forecast for remaining days (proportional)
                    if days_in_month > 0:
                        forecast_remaining_liters = full_forecast_liters * (remaining_days / days_in_month)
                    else:
                        forecast_remaining_liters = 0.0

                    blended_full_month_liters = actual_liters + forecast_remaining_liters

                    actual_m3 = actual_liters / LITERS_PER_M3
                    forecast_m3 = blended_full_month_liters / LITERS_PER_M3

                else:
                    # Future months → forecast only
                    actual_liters = None
                    full_forecast_liters = district_monthly_forecast_liters[district_name].get(m, 0.0)
                    actual_m3 = None
                    forecast_m3 = full_forecast_liters / LITERS_PER_M3

                monthly_trend_map[key] = {
                    "actual_m3": actual_m3,
                    "forecast_m3": forecast_m3,
                }

            rec["monthly_trend_current_year"] = monthly_trend_map

        # ----- Add ranking (1 = highest next-month demand) -----
        log_step("Ranking districts by next-month demand...")
        recs_sorted = sorted(
            recommendations,
            key=lambda r: r['district_forecast_next_month_m3'],
            reverse=True
        )
        for rank, rec in enumerate(recs_sorted, start=1):
            rec['district_rank_by_next_month_demand'] = rank

        # ----- Build overall monthly trend for current year (Option B) -----
        log_step("Building overall monthly_trend_current_year...")
        overall_monthly_trend_current_year = {}
        for m in current_year_months:
            key = m.strftime("%Y-%m")

            if m < first_day_current_month:
                # Past months: only actual (from aggregated overall_monthly_liters)
                actual_liters = overall_monthly_liters.get(m, 0.0)
                full_forecast_liters = None
                actual_m3 = actual_liters / LITERS_PER_M3
                forecast_m3 = None

            elif m == first_day_current_month:
                # Current month: hybrid
                actual_liters = overall_monthly_liters.get(m, 0.0)
                full_forecast_liters = overall_monthly_forecast_current_year_liters.get(m, 0.0)

                days_in_month = calendar.monthrange(m.year, m.month)[1]
                days_elapsed = today.day
                remaining_days = max(days_in_month - days_elapsed, 0)

                if days_in_month > 0:
                    forecast_remaining_liters = full_forecast_liters * (remaining_days / days_in_month)
                else:
                    forecast_remaining_liters = 0.0

                blended_full_month_liters = actual_liters + forecast_remaining_liters
                actual_m3 = actual_liters / LITERS_PER_M3
                forecast_m3 = blended_full_month_liters / LITERS_PER_M3

            else:
                # Future months: only forecast
                actual_liters = None
                full_forecast_liters = overall_monthly_forecast_current_year_liters.get(m, 0.0)
                actual_m3 = None
                forecast_m3 = full_forecast_liters / LITERS_PER_M3

            overall_monthly_trend_current_year[key] = {
                "actual_m3": actual_m3,
                "forecast_m3": forecast_m3,
            }

        save_recommendations(db, recs_sorted)
        save_overall_summary(db, recs_sorted, overall_monthly_trend_current_year)
        visualize_stations(stations_df, recs_sorted)

        # Print summary lines (good for logs / thesis demo)
        log_step("Printing per-district summary to logs...")
        for rec in recs_sorted:
            print(
                f"[{rec['district']}] "
                f"Rank: {rec['district_rank_by_next_month_demand']} | "
                f"Trend: {rec['district_trend']} | "
                f"History: {rec['district_total_m3']:.2f} m³ | "
                f"Next month: {rec['district_forecast_next_month_m3']:.2f} m³ | "
                f"Next 12 months: {rec['district_forecast_12m_m3']:.2f} m³ | "
                f"Recommended point: ({rec['lat']}, {rec['lng']})"
            )

    # Create yearly/monthly demand graph for Federated admin (all years)
    plot_overall_monthly_demand(overall_monthly_liters)

    log_step(f"===== AI job finished in {time.time() - job_start:.2f}s =====")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["firestore", "csv"], default="firestore")
    parser.add_argument("--csv_path", type=str, default="synthetic_stations.csv")
    args = parser.parse_args()
    main(mode=args.mode, csv_path=args.csv_path)
