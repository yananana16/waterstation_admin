#!/usr/bin/env python3
# ai_analytics.py
# End-to-end analytics + AI for Water Station platform.
# - Reads Firestore sales + stations
# - Cleans & aggregates
# - KMeans market segmentation -> new station location recs (per waterType + district, inside polygon)
# - Optional: Prophet forecasting (auto-skip if not installed)
# - Optional: XGBoost churn (auto-skip if not installed)
# Outputs CSVs to ./out and (optionally) writes recs to Firestore.

from google.cloud import firestore
from google.oauth2 import service_account
import os
import sys
import math
import json
import random
from dataclasses import dataclass
from typing import Dict, List, Any, Optional, Tuple
from collections import defaultdict
from datetime import datetime, timezone, timedelta

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.neighbors import KDTree

# Geo libraries
import geopandas as gpd
from shapely.geometry import Point

# Optional deps
try:
    from prophet import Prophet  # pip install prophet
    _HAS_PROPHET = True
except Exception:
    _HAS_PROPHET = False

try:
    from xgboost import XGBClassifier  # pip install xgboost
    _HAS_XGB = True
except Exception:
    _HAS_XGB = False

import pytz
import logging

# ----------------------------
# CONFIG
# ----------------------------
ASIA_MANILA = pytz.timezone("Asia/Manila")
OUT_DIR = os.path.join(os.getcwd(), "out")
os.makedirs(OUT_DIR, exist_ok=True)

ORDERS_COLLECTION = "orders"
STATIONS_COLLECTION = "station_owners"

WRITE_RECS_TO_FIRESTORE = False
ADMIN_RECS_COLLECTION = "admin_recommendations"

# KMeans knobs
MIN_ORDERS_PER_CLUSTER = 8
MIN_CLUSTER_SALES = 800.0
RECOMMEND_TOP_K = 5
MIN_DISTANCE_TO_EXISTING_M = 400
KMEANS_K_PER_WATERTYPE = 6

# ----------------------------
# Utilities
# ----------------------------
def to_dt(ts) -> datetime:
    if ts is None:
        return None
    if isinstance(ts, datetime):
        return ts.astimezone(ASIA_MANILA) if ts.tzinfo else ASIA_MANILA.localize(ts)
    try:
        dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(ASIA_MANILA)
    except Exception:
        return None

def to_num(x, default=0.0) -> float:
    if x is None:
        return float(default)
    try:
        return float(x)
    except Exception:
        try:
            return float(str(x).strip())
        except Exception:
            return float(default)

def haversine_m(lat1, lon1, lat2, lon2) -> float:
    R = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dlmb/2)**2
    return 2 * R * math.asin(math.sqrt(a))

# ----------------------------
# Firestore setup
# ----------------------------
def connect_firestore():
    """Initialize and return a Firestore client."""
    from google.cloud import firestore
    logging.info("Connecting to Firestore…")
    return firestore.Client()


def fetch_data(db):
    """Fetch stations and sales as DataFrames."""
    logging.info("Fetching stations & sales…")
    stations_df = fetch_stations(db)
    sales_df = fetch_sales(db)
    return stations_df, sales_df
KEY_PATH = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")
creds = service_account.Credentials.from_service_account_file(KEY_PATH)

def get_db() -> firestore.Client:
    return firestore.Client(credentials=creds, project=creds.project_id)

# ----------------------------
# Load district polygons
# ----------------------------
try:
    DISTRICTS_GDF = gpd.read_file("iloilo_city_7_districts.geojson")
    # Use the 'name' property as the district name
    DISTRICTS_GDF = DISTRICTS_GDF.rename(columns={"name": "districtName"})
    DISTRICTS_GDF = DISTRICTS_GDF[["districtName", "geometry"]]
except Exception as e:
    print(f"Warning: could not load district polygons: {e}")
    DISTRICTS_GDF = None

# ----------------------------
# Fetch data
# ----------------------------
def fetch_sales(db) -> pd.DataFrame:
    rows = []
    query = db.collection("orders").where(field_path="status", op_string="in", value=["Completed", "Delivered"])
    for doc in query.stream():
        s = doc.to_dict() or {}
        created = to_dt(s.get("createdAt") or s.get("timestamp"))
        total_price = to_num(s.get("totalPrice", s.get("total_amount")), 0)
        cust = s.get("customer_coords") or {}
        clat, clng = cust.get("lat"), cust.get("lng")
        if clat is None or clng is None:
            ship = s.get("shippingAddress") or {}
            clat, clng = ship.get("latitude"), ship.get("longitude")

        station_ids = []
        if s.get("stationOwnerId"):
            station_ids = [s["stationOwnerId"]]
        elif isinstance(s.get("stationOwnerIds"), list):
            station_ids = [sid for sid in s["stationOwnerIds"] if isinstance(sid, str)]

        per_meta = s.get("perStationMeta") or {}
        for sid in (station_ids or [None]):
            delivery_distance_m = None
            if sid and isinstance(per_meta.get(sid), dict):
                delivery_distance_m = per_meta[sid].get("delivery_distance_m")
            rows.append({
                "saleId": doc.id,
                "createdAt": created,
                "status": s.get("status"),
                "stationOwnerId": sid,
                "customerId": s.get("customerId"),
                "customer_lat": to_num(clat, None),
                "customer_lng": to_num(clng, None),
                "delivery_distance_m": to_num(delivery_distance_m, None),
                "totalPrice": total_price,
            })
    df = pd.DataFrame(rows)
    if not df.empty:
        df = df.dropna(subset=["createdAt"])
    return df

def fetch_stations(db) -> pd.DataFrame:
    rows = []
    for station_doc in db.collection("station_owners").stream():
        station_id = station_doc.id
        sdata = station_doc.to_dict() or {}
        loc = sdata.get("location") or {}
        lat = loc.get("latitude") or loc.get("lat") or (loc.get("map", {}) or {}).get("lat")
        lng = loc.get("longitude") or loc.get("lng") or (loc.get("map", {}) or {}).get("lng")
        district = sdata.get("districtName") or sdata.get("district") \
                   or (sdata.get("address") or {}).get("district") \
                   or (sdata.get("location") or {}).get("districtName")
        waterType = None
        products_ref = db.collection("station_owners").document(station_id).collection("products")
        for pdoc in products_ref.stream():
            pdata = pdoc.to_dict() or {}
            if pdata.get("waterType"):
                waterType = pdata["waterType"]
                break
        if not waterType:
            waterType = sdata.get("waterType")
        rows.append({
            "stationOwnerId": station_id,
            "waterType": waterType,
            "station_lat": to_num(lat, None),
            "station_lng": to_num(lng, None),
            "district": district
        })
    df = pd.DataFrame(rows)
    return df.dropna(subset=["station_lat", "station_lng", "waterType"])

# ----------------------------
# Feature tables
# ----------------------------
def build_station_joined_sales(sales_df: pd.DataFrame, stations_df: pd.DataFrame) -> pd.DataFrame:
    if sales_df.empty or stations_df.empty:
        return pd.DataFrame()
    stations_slim = stations_df[["stationOwnerId", "waterType", "station_lat", "station_lng", "district"]].drop_duplicates()
    out = sales_df.merge(stations_slim, on="stationOwnerId", how="left")
    return out

def timeseries_by_station(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df
    t = df.copy()
    t["date"] = t["createdAt"].dt.tz_convert(ASIA_MANILA).dt.date
    agg = (t.groupby(["stationOwnerId", "waterType", "date"])
             .agg(orders=("saleId", "nunique"),
                  totalSales=("totalPrice", "sum"))
             .reset_index())
    return agg

def rfm_by_customer(df: pd.DataFrame, as_of: Optional[datetime] = None) -> pd.DataFrame:
    if df.empty:
        return df
    as_of = as_of or datetime.now(tz=ASIA_MANILA)
    t = df.dropna(subset=["customerId"]).copy()
    last = t.groupby("customerId")["createdAt"].max().reset_index().rename(columns={"createdAt": "last_order"})
    freq = t.groupby("customerId")["saleId"].nunique().reset_index().rename(columns={"saleId": "frequency"})
    mon = t.groupby("customerId")["totalPrice"].mean().reset_index().rename(columns={"totalPrice": "avgSpend"})
    rfm = last.merge(freq, on="customerId").merge(mon, on="customerId")
    rfm["recency_days"] = (as_of - rfm["last_order"]).dt.days
    return rfm

# ----------------------------
# KMeans recommendations
# ----------------------------
@dataclass
class Recommendation:
    waterType: str
    lat: float
    lng: float
    est_orders_per_month: int
    est_monthly_sales: float
    nearest_station_id: Optional[str]
    nearest_station_distance_m: float
    cluster_orders: int
    cluster_sales: float
    district: Optional[str] = None

from sklearn.preprocessing import StandardScaler
from sklearn.cluster import MiniBatchKMeans

def recommend_new_locations(
    df_joined: pd.DataFrame,
    stations_df: pd.DataFrame,
    k_per_type: int = KMEANS_K_PER_WATERTYPE,
    min_orders: int = MIN_ORDERS_PER_CLUSTER,
    min_sales: float = MIN_CLUSTER_SALES,
    min_near_dist_m: float = MIN_DISTANCE_TO_EXISTING_M,
    top_k: int = RECOMMEND_TOP_K,
    rfm_df: Optional[pd.DataFrame] = None,      # RFM table (optional)
    forecast_df: Optional[pd.DataFrame] = None  # Prophet forecast table (optional)
) -> List[Recommendation]:
    """
    Recommend new water station locations using MiniBatchKMeans clustering,
    demand features, polygon filtering, and scoring with soft penalties.
    """

    recs: List[Recommendation] = []

    # Group by waterType + district if available
    group_cols = ["waterType", "district"] if "district" in stations_df.columns else ["waterType"]

    for group_vals, sdf in stations_df.groupby(group_cols):
        if isinstance(group_vals, tuple):
            wtype, district = group_vals
        else:
            wtype, district = group_vals, None

        # Filter joined sales by waterType (and district if present)
        cust = df_joined[
            (df_joined["waterType"] == wtype) &
            ((df_joined["district"] == district) if district else True)
        ].dropna(subset=["customer_lat", "customer_lng"]).copy()

        if cust.empty:
            continue

        # Add monthly bucket
        cust["yyyymm"] = cust["createdAt"].dt.tz_convert(ASIA_MANILA).dt.to_period("M")

        # Aggregate orders & sales per customer per month
        agg = (
            cust.groupby(["customer_lat", "customer_lng", "yyyymm"])
            .agg(orders=("saleId", "nunique"), sales=("totalPrice", "sum"))
            .reset_index()
        )

        # Aggregate per customer location across time
        pts = (
            agg.groupby(["customer_lat", "customer_lng"])
            .agg(orders=("orders", "sum"), sales=("sales", "sum"))
            .reset_index()
        )

        # Optional: merge RFM features (frequency, spend)
        if rfm_df is not None and not rfm_df.empty:
            pts = pts.merge(
                rfm_df[["customerId", "frequency", "avgSpend"]],
                left_on="customer_lat",   # ⚠️ adjust join key if needed
                right_on="customerId",
                how="left"
            )
            pts["rfm_weight"] = 1 + (pts["frequency"].fillna(1) / 10.0) + (pts["avgSpend"].fillna(0) / 100.0)
        else:
            pts["rfm_weight"] = 1.0

        # Features for clustering (lat, lng, orders, sales)
        X = pts[["customer_lat", "customer_lng", "orders", "sales"]].values
        X = StandardScaler().fit_transform(X)

        # Choose K adaptively
        max_k = min(k_per_type, len(pts))
        k = max(1, min(max_k, len(pts) // 3))

        km = MiniBatchKMeans(
            n_clusters=k,
            batch_size=100,
            random_state=42,
            max_iter=100,
            n_init="auto"
        )
        pts["cluster"] = km.fit_predict(X)

        # Cluster-level aggregation
        clusters = (
            pts.groupby("cluster")
            .agg(
                cluster_orders=("orders", "sum"),
                cluster_sales=("sales", "sum"),
                lat=("customer_lat", "mean"),
                lng=("customer_lng", "mean"),
                weight=("rfm_weight", "mean")
            )
            .reset_index()
        )

        months = max(1, len(agg["yyyymm"].unique()))
        scored_clusters = []

        for _, row in clusters.iterrows():
            est_orders = int(row["cluster_orders"] // months)
            est_sales = float(row["cluster_sales"] / months)
            lat, lng = float(row["lat"]), float(row["lng"])

            near_id, dist_m = _nearest_station(lat, lng, sdf)

            # Base score (orders, sales, distance, weighted)
            score = (
                0.4 * est_orders * row["weight"] +
                0.3 * (est_sales * row["weight"]) / 100 +
                0.1 * (dist_m / 100)
            )

            # Optional: demand growth adjustment
            if forecast_df is not None and not forecast_df.empty:
                fc = forecast_df[forecast_df["stationOwnerId"].isin(sdf["stationOwnerId"])]
                if not fc.empty:
                    growth_rate = (fc["yhat"].iloc[-1] - fc["yhat"].iloc[0]) / max(1, fc["yhat"].iloc[0])
                    score += 0.2 * growth_rate

            # Soft penalties
            if row["cluster_orders"] < min_orders:
                score -= 2
            if row["cluster_sales"] < min_sales:
                score -= 2
            if dist_m < min_near_dist_m:
                score -= 1

            # Polygon check
            if district and DISTRICTS_GDF is not None:
                poly = DISTRICTS_GDF.loc[DISTRICTS_GDF["districtName"] == district, "geometry"]
                if not poly.empty and not poly.squeeze().contains(Point(lng, lat)):
                    logging.debug(
                        f"⚠️ Skipped (outside district polygon) → "
                        f"Lat={lat:.5f}, Lng={lng:.5f} District={district}"
                    )
                    continue

            scored_clusters.append((score, row, est_orders, est_sales, near_id, dist_m))

        # Pick top-k clusters by score
        scored_clusters.sort(key=lambda x: x[0], reverse=True)
        for score, row, est_orders, est_sales, near_id, dist_m in scored_clusters[:top_k]:
            recs.append(
                Recommendation(
                    waterType=wtype,
                    lat=float(row["lat"]),
                    lng=float(row["lng"]),
                    est_orders_per_month=max(est_orders, 1),
                    est_monthly_sales=max(est_sales, 0.0),
                    nearest_station_id=near_id,
                    nearest_station_distance_m=dist_m,
                    cluster_orders=int(row["cluster_orders"]),
                    cluster_sales=float(row["cluster_sales"]),
                    district=district,
                )
            )

    return recs
def _nearest_station(lat: float, lng: float, sdf: pd.DataFrame) -> Tuple[Optional[str], float]:
    coords = sdf[["station_lat", "station_lng"]].values
    if coords.shape[0] == 0:
        return None, float("inf")
    min_d = float("inf")
    min_id = None
    for _, r in sdf.iterrows():
        d = haversine_m(lat, lng, r["station_lat"], r["station_lng"])
        if d < min_d:
            min_d = d
            min_id = r["stationOwnerId"]
    return min_id, float(min_d)

# ----------------------------
# Forecasting & Churn (unchanged)
# ----------------------------
def prophet_forecast(daily_df: pd.DataFrame, horizon_days: int = 30) -> pd.DataFrame:
    if not _HAS_PROPHET or daily_df.empty:
        return pd.DataFrame()
    results = []
    for sid, g in daily_df.groupby("stationOwnerId"):
        dfm = g.sort_values("date")[["date", "totalSales"]].rename(columns={"date": "ds", "totalSales": "y"})
        dfm["ds"] = pd.to_datetime(dfm["ds"])
        if len(dfm) < 7:
            continue
        m = Prophet(daily_seasonality=True, weekly_seasonality=True)
        m.fit(dfm)
        future = m.make_future_dataframe(periods=horizon_days, freq="D")
        fc = m.predict(future)
        fc = fc[["ds", "yhat", "yhat_lower", "yhat_upper"]].copy()
        fc["stationOwnerId"] = sid
        results.append(fc)
    if results:
        out = pd.concat(results, ignore_index=True)
        out["date"] = out["ds"].dt.date
        return out.drop(columns=["ds"])
    return pd.DataFrame()

def build_churn_dataset(sales_df: pd.DataFrame, cutoff_days: int = 30) -> pd.DataFrame:
    if sales_df.empty:
        return pd.DataFrame()
    as_of = sales_df["createdAt"].max()
    rfm = rfm_by_customer(sales_df, as_of=as_of)
    if rfm.empty:
        return rfm
    rfm["churn"] = (rfm["recency_days"] > cutoff_days).astype(int)
    ds = rfm[["customerId", "recency_days", "frequency", "avgSpend", "churn"]].dropna()
    return ds

def train_churn_model(ds: pd.DataFrame):
    if not _HAS_XGB or ds.empty:
        return None, None
    X = ds[["recency_days", "frequency", "avgSpend"]].values
    y = ds["churn"].values
    if len(np.unique(y)) < 2 or len(y) < 20:
        return None, None
    model = XGBClassifier(
        max_depth=4, n_estimators=120, learning_rate=0.08, subsample=0.9,
        colsample_bytree=0.9, random_state=42, n_jobs=2, reg_lambda=1.0
    )
    model.fit(X, y)
    return model, ["recency_days", "frequency", "avgSpend"]

# ----------------------------
# Firestore write-back
# ----------------------------
def write_recommendations(db, recs: List[Recommendation]):
    if not WRITE_RECS_TO_FIRESTORE or not recs:
        return
    batch = db.batch()
    now = datetime.now(tz=ASIA_MANILA)
    for r in recs:
        doc_ref = db.collection(ADMIN_RECS_COLLECTION).document()
        payload = {
            "createdAt": now,
            "type": "new_station_location",
            "waterType": r.waterType,
            "location": {"lat": r.lat, "lng": r.lng},
            "estimated": {
                "orders_per_month": r.est_orders_per_month,
                "sales_per_month": r.est_monthly_sales
            },
            "nearestStation": {
                "stationOwnerId": r.nearest_station_id,
                "distance_m": r.nearest_station_distance_m
            },
            "cluster_stats": {
                "orders": r.cluster_orders,
                "sales": r.cluster_sales
            }
        }
        batch.set(doc_ref, payload)
    batch.commit()

# ----------------------------
# MAIN
# ----------------------------
def main():
    print("Connecting to Firestore…")
    db = get_db()

    print("Fetching stations…")
    stations_df = fetch_stations(db)
    print(f"Stations: {len(stations_df)} with coords & waterType")

    print("Fetching sales…")
    sales_df = fetch_sales(db)
    print(f"Sales rows (exploded per-station): {len(sales_df)}")

    if sales_df.empty or stations_df.empty:
        print("No data to process. Exiting.")
        return

    print("Joining sales with station metadata…")
    joined = build_station_joined_sales(sales_df, stations_df)
    joined = joined.dropna(subset=["stationOwnerId", "waterType"])
    print(f"Joined rows: {len(joined)}")

    # ---------------- Build feature tables ----------------
    print("Building daily station time series…")
    ts_daily = timeseries_by_station(joined)
    ts_daily.to_csv(os.path.join(OUT_DIR, "timeseries_daily_per_station.csv"), index=False)

    print("Building RFM (customer) table…")
    rfm = rfm_by_customer(joined)
    rfm.to_csv(os.path.join(OUT_DIR, "rfm_by_customer.csv"), index=False)

    # ---------------- Recommendations (KMeans) ------------
    print("Running KMeans location recommendations…")
    recs = recommend_new_locations(joined, stations_df)
    recs_out = pd.DataFrame([r.__dict__ for r in recs])
    recs_csv = os.path.join(OUT_DIR, "recommendations_new_stations.csv")
    if not recs_out.empty:
        recs_out.to_csv(recs_csv, index=False)
        print(f"Saved recommendations -> {recs_csv}")
    else:
        print("No eligible recommendations found with current thresholds.")

    # Optional: Forecasting
    if _HAS_PROPHET:
        print("Prophet detected: forecasting 30 days per station…")
        fc = prophet_forecast(ts_daily, horizon_days=30)
        if not fc.empty:
            fc.to_csv(os.path.join(OUT_DIR, "forecast_totalSales_per_station.csv"), index=False)
            print("Saved Prophet forecasts.")
        else:
            print("Forecast skipped (not enough data per station).")
    else:
        print("Prophet not installed — skipping forecasting. (pip install prophet)")

    # Optional: Churn
    ds = build_churn_dataset(joined, cutoff_days=30)
    if _HAS_XGB:
        model, feat = train_churn_model(ds)
        if model is not None:
            print(f"Churn model trained with features: {feat}")
            # You can serialize with joblib if desired.
        else:
            print("Churn training skipped (insufficient class balance or data).")
    else:
        print("XGBoost not installed — skipping churn model. (pip install xgboost)")

    # Optional: write Firestore admin recs
    if WRITE_RECS_TO_FIRESTORE and recs:
        print("Writing recommendations to Firestore…")
        write_recommendations(db, recs)
        print("Recommendations written.")
    else:
        if WRITE_RECS_TO_FIRESTORE:
            print("No recs to write.")

    # Helpful topline summaries
    try:
        print("\n=== Topline ===")
        by_type = joined.groupby("waterType")["totalPrice"].sum().sort_values(ascending=False)
        print("Sales by waterType (PHP):")
        print(by_type.round(2))

        by_station = joined.groupby(["stationOwnerId", "waterType"])["totalPrice"].sum() \
                           .sort_values(ascending=False).head(10)
        print("\nTop 10 stations by sales:")
        print(by_station.round(2))
    except Exception:
        pass

if __name__ == "__main__":
    main()
