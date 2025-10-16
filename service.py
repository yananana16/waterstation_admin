import math
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
from sklearn.cluster import DBSCAN
import folium
from folium.plugins import MarkerCluster, HeatMap
import argparse
from datetime import datetime

def save_recommendations(db, recommendations):
    """
    Save recommendations to Firestore.
    Each district will only have ONE doc (overwrite mode).
    Old recommendations get replaced by the latest.
    """
    recs_ref = db.collection("station_recommendations")

    for rec in recommendations:
        # Add timestamp
        rec['createdAt'] = datetime.utcnow()

        # Use district name as the doc ID (overwrite per district)
        doc_id = rec['district'].replace(" ", "_")  # safer IDs
        recs_ref.document(doc_id).set(rec)

    print(f"Saved {len(recommendations)} recommendations (overwrite mode).")

# -------------------------------
# Initialize Firebase Admin SDK
# -------------------------------
def init_firestore():
    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
    return firestore.client()

# -------------------------------
# Fetch sales and station data from Firestore
# -------------------------------
def fetch_data_firestore(db):
    stations_ref = db.collection('station_owners')
    stations_data = []

    for station in stations_ref.stream():
        station_dict = station.to_dict()
        station_id = station.id
        district_id = station_dict.get('districtID')
        district_name = station_dict.get('districtName')
        lat = station_dict.get('location', {}).get('latitude')
        lng = station_dict.get('location', {}).get('longitude')
        water_type = station_dict.get('waterType')

        # Aggregate total sales for this station
        sales_ref = station.reference.collection('sales')
        sales_values = []
        for sale in sales_ref.stream():
            sale_dict = sale.to_dict()
            raw_value = sale_dict.get('totalPrice') or sale_dict.get('total_amount') or 0
            try:
                sales_values.append(float(raw_value))
            except (ValueError, TypeError):
                continue

        total_sales = sum(sales_values) if sales_values else 0

        # Skip invalid coordinates
        if pd.isna(lat) or pd.isna(lng):
            continue

        stations_data.append({
            'station_id': station_id,
            'district_id': district_id,
            'district_name': district_name,
            'lat': lat,
            'lng': lng,
            'water_type': water_type,
            'total_sales': total_sales
        })
    
    print(f"Fetched {len(stations_data)} stations from Firestore.")
    return pd.DataFrame(stations_data)

# -------------------------------
# Fetch data from CSV (for testing)
# -------------------------------
def fetch_data_csv(csv_path):
    df = pd.read_csv(csv_path)
    print(f"Loaded {len(df)} stations from CSV: {csv_path}")
    return df

# -------------------------------
# Dynamic Clustering (DBSCAN)
# -------------------------------
def dynamic_clustering(stations_df):
    locations = stations_df[['lat', 'lng']].values
    clustering = DBSCAN(eps=0.01, min_samples=2, metric='haversine').fit(np.radians(locations))
    stations_df.loc[:, 'cluster'] = clustering.labels_
    return stations_df

# -------------------------------
# Recommendation for a district
# -------------------------------
def recommend_best_location_for_district(stations_df, district_name, range_radius=50):
    district_df = stations_df[stations_df['district_name'] == district_name].copy()

    if len(district_df) < 2:
        print(f"Not enough stations in {district_name} to perform clustering.")
        return None

    district_df = dynamic_clustering(district_df)

    cluster_sales = district_df.groupby('cluster')['total_sales'].sum()
    highest_density_cluster = cluster_sales.idxmax()

    recommended_stations = district_df[district_df['cluster'] == highest_density_cluster]

    weighted_lat = np.average(recommended_stations['lat'], weights=recommended_stations['total_sales'])
    weighted_lng = np.average(recommended_stations['lng'], weights=recommended_stations['total_sales'])

    top_station = recommended_stations.loc[recommended_stations['total_sales'].idxmax()]

    explanation = (
        f"The recommended location for {district_name} is based on clustering existing stations. "
        f"The cluster with the highest sales concentration was selected. "
        f"The top-performing station is {top_station['station_id']} "
        f"with {top_station['total_sales']} sales. "
        f"The new recommended location is within {range_radius} meters of "
        f"({weighted_lat}, {weighted_lng})."
    )

    return {
        'district': district_name,
        'lat': weighted_lat,
        'lng': weighted_lng,
        'range_radius': range_radius,
        'explanation': explanation
    }

# -------------------------------
# Visualization
# -------------------------------
def visualize_stations(stations_df, recommendations, map_filename='recommendations_map.html'):
    center_lat, center_lng = stations_df[['lat', 'lng']].mean()
    m = folium.Map(location=[center_lat, center_lng], zoom_start=12)
    
    marker_cluster = MarkerCluster().add_to(m)
    for _, row in stations_df.iterrows():
        folium.Marker(
            location=[row['lat'], row['lng']],
            popup=f"{row['station_id']} ({row['water_type']})",
            icon=folium.Icon(color='blue')
        ).add_to(marker_cluster)
    
    for rec in recommendations:
        folium.Marker(
            location=[rec['lat'], rec['lng']],
            popup=f"Recommended {rec['district']}",
            icon=folium.Icon(color='red', icon='star')
        ).add_to(m)
        folium.Circle(
            location=[rec['lat'], rec['lng']],
            radius=rec['range_radius'],
            color='green',
            fill=True,
            fill_opacity=0.2
        ).add_to(m)
    
    add_heatmap(m, stations_df)
    m.save(map_filename)
    print(f"Map saved as {map_filename}")

def add_heatmap(map_object, stations_df):
    heat_data = [[row['lat'], row['lng'], row['total_sales']] for _, row in stations_df.iterrows()]
    HeatMap(heat_data).add_to(map_object)

# -------------------------------
# Main
# -------------------------------
def main(mode="csv", csv_path="synthetic_stations.csv"):
    if mode == "firestore":
        db = init_firestore()
        stations_df = fetch_data_firestore(db)
    else:
        stations_df = fetch_data_csv(csv_path)

    recommendations = []

    for district_name in stations_df['district_name'].dropna().unique():
        rec = recommend_best_location_for_district(stations_df, district_name, range_radius=50)
        if rec:
            recommendations.append(rec)
            print(f"Recommendation for {district_name}: ({rec['lat']}, {rec['lng']})")

    if recommendations:
        if mode == "firestore":
            save_recommendations(db, recommendations)  # only save if Firestore mode
            print("All recommendations saved to Firestore.")
        visualize_stations(stations_df, recommendations)
    else:
        print("No recommendations generated.")

# -------------------------------
# Run
# -------------------------------
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["firestore", "csv"], default="csv")
    parser.add_argument("--csv_path", type=str, default="synthetic_stations.csv")
    args = parser.parse_args()

    main(mode=args.mode, csv_path=args.csv_path)
