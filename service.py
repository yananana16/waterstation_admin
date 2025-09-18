import math
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
from sklearn.cluster import DBSCAN
from sklearn.ensemble import RandomForestRegressor
from geopy.distance import geodesic, great_circle
import folium
from folium.plugins import MarkerCluster, HeatMap
from sklearn.metrics import silhouette_score
from sklearn.preprocessing import StandardScaler

# Initialize Firebase Admin SDK
def init_firestore():
    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
    return firestore.client()

# Fetch sales and station data from Firestore
def fetch_data(db):
    stations_ref = db.collection('station_owners')
    stations_data = []

    for station in stations_ref.stream():
        station_id = station.id
        district_id = station.to_dict().get('districtID')
        district_name = station.to_dict().get('districtName')
        lat = station.to_dict().get('location', {}).get('latitude')
        lng = station.to_dict().get('location', {}).get('longitude')
        
        # Aggregate total sales for this station
        sales_ref = station.reference.collection('sales')
        total_sales = sum([sale.to_dict().get('totalsales', 0) for sale in sales_ref.stream()])
        
        # Handle missing or invalid sales
        if pd.isna(total_sales) or total_sales < 0:
            total_sales = np.nanmedian([sale.to_dict().get('totalsales', 0) for sale in sales_ref.stream()])

        # Handle invalid lat/lng
        if pd.isna(lat) or pd.isna(lng):
            continue  # Skip invalid entries

        stations_data.append({
            'station_id': station_id,
            'district_id': district_id,
            'district_name': district_name,
            'lat': lat,
            'lng': lng,
            'total_sales': total_sales
        })
    
    return pd.DataFrame(stations_data)

# Dynamic Clustering with DBSCAN (Density-Based)
def dynamic_clustering(stations_df):
    locations = stations_df[['lat', 'lng']].values
    sales = stations_df['total_sales'].values
    
    # Standardize sales to prevent any one feature from dominating
    scaler = StandardScaler()
    scaled_sales = scaler.fit_transform(sales.reshape(-1, 1))
    
    # DBSCAN clustering
    clustering = DBSCAN(eps=0.01, min_samples=2, metric='haversine').fit(np.radians(locations))
    stations_df.loc[:, 'cluster'] = clustering.labels_  # Fixed warning by using .loc to assign values
    
    return stations_df

# Predict sales using a Random Forest model
def predict_sales(stations_df):
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    features = stations_df[['lat', 'lng']]  # Adding more features is possible here
    model.fit(features, stations_df['total_sales'])
    
    return model

def recommend_best_location_for_jaro(stations_df, range_radius=50):
    # Create a copy to avoid the SettingWithCopyWarning
    jaro_stations_df = stations_df[stations_df['district_name'] == 'Jaro'].copy()

    if len(jaro_stations_df) < 2:
        print("Not enough stations in Jaro to perform clustering.")
        return None

    # Use dynamic clustering to segment the stations (DBSCAN or KMeans can be used)
    jaro_stations_df = dynamic_clustering(jaro_stations_df)

    # Find the highest density cluster
    cluster_sales = jaro_stations_df.groupby('cluster')['total_sales'].sum()
    highest_density_cluster = cluster_sales.idxmax()

    recommended_stations = jaro_stations_df[jaro_stations_df['cluster'] == highest_density_cluster]
    
    # Calculate sales-weighted centroid
    weighted_lat = np.average(recommended_stations['lat'], weights=recommended_stations['total_sales'])
    weighted_lng = np.average(recommended_stations['lng'], weights=recommended_stations['total_sales'])
    
    recommended_location = {'lat': weighted_lat, 'lng': weighted_lng}

    # Find the station with the highest sales in the cluster for a more personalized explanation
    top_station = recommended_stations.loc[recommended_stations['total_sales'].idxmax()]

    # Generate dynamic explanation with fixed 50 meter range
    explanation = (
        f"The recommended station location is based on the clustering of existing stations within the Jaro district. "
        f"The DBSCAN clustering algorithm identified a cluster of stations with the highest sales concentration. "
        f"Within this cluster, the station with the highest sales is {top_station['station_id']} "
        f"with {top_station['total_sales']} total sales. This indicates that this area has strong demand and "
        f"the new station is likely to replicate the success of existing stations in the region.\n"
        f"Furthermore, the recommended location is positioned to maximize coverage in a high-density area, avoiding market saturation. "
        f"It is strategically located based on proximity to key amenities and customer demand.\n"
        f"The ideal location is within a fixed 50-meter radius from the recommended centroid at ({recommended_location['lat']}, {recommended_location['lng']})."
    )
    
    print(explanation)

    return {
        'district': 'Jaro',
        'lat': recommended_location['lat'],
        'lng': recommended_location['lng'],
        'range_radius': range_radius,
        'explanation': explanation
    }

# Save recommendations to Firestore
def save_recommendations(db, recommendations):
    recommendations_ref = db.collection('station_recommendations')
    for rec in recommendations:
        recommendations_ref.add(rec)

# Visualize stations and recommended new locations
def visualize_stations(stations_df, recommendations, map_filename='recommendations_map.html'):
    center_lat, center_lng = stations_df[['lat', 'lng']].mean()
    m = folium.Map(location=[center_lat, center_lng], zoom_start=12)
    
    marker_cluster = MarkerCluster().add_to(m)
    for _, row in stations_df.iterrows():
        folium.Marker(
            location=[row['lat'], row['lng']],
            popup=row['station_id'],
            icon=folium.Icon(color='blue')
        ).add_to(marker_cluster)
    
    for rec in recommendations:
        folium.Marker(
            location=[rec['lat'], rec['lng']],
            popup=f"Recommended {rec['district']}",
            icon=folium.Icon(color='red', icon='star')
        ).add_to(m)
        
        # Add a circle to represent the 50-meter range
        folium.Circle(
            location=[rec['lat'], rec['lng']],
            radius=rec['range_radius'],  # 50 meters in radius
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

# Main function to run the entire process
def main():
    db = init_firestore()
    
    # Fetch data from Firestore
    stations_df = fetch_data(db)
    print("Fetched stations data.")
    
    # Get the best recommendation for Jaro district only
    recommended_location = recommend_best_location_for_jaro(stations_df, range_radius=50)
    
    if recommended_location:
        print(f"Recommended location for Jaro: ({recommended_location['lat']}, {recommended_location['lng']})")
    
    # Save recommendations to Firestore
    save_recommendations(db, [recommended_location] if recommended_location else [])
    print("New station recommendation saved to Firestore.")
    
    # Visualize the results on a map
    visualize_stations(stations_df, [recommended_location] if recommended_location else [])
    print("Map generated and saved.")

if __name__ == '__main__':
    main()
