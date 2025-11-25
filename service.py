import math
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
from sklearn.cluster import DBSCAN
import folium
from folium.plugins import MarkerCluster, HeatMap
from collections import defaultdict
import argparse
from datetime import datetime
from textblob import TextBlob  # Import TextBlob for sentiment analysis

def analyze_sentiment(comment):
    """
    Perform sentiment analysis on the feedback comment.
    Returns 'positive', 'neutral', or 'negative'.
    """
    blob = TextBlob(comment)
    sentiment_score = blob.sentiment.polarity
    if sentiment_score > 0:
            sentiment = 'positive'
    elif sentiment_score < 0:
            sentiment = 'negative'
    else:
            sentiment = 'neutral'
    return sentiment, sentiment_score

def save_recommendations(db, recommendations, district_sentiments):
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
        
        # Add sentiment from the district-level sentiment data
        district_sentiment = district_sentiments.get(rec['district'], 'neutral')
        rec['district_sentiment'] = district_sentiment  # Save sentiment at district level

        recs_ref.document(doc_id).set(rec)

    print(f"Saved {len(recommendations)} recommendations (overwrite mode).")

# -------------------------------
# Initialize Firebase Admin SDK
# -------------------------------
def init_firestore():
    # Load credentials and initialize the Firebase app only if it isn't
    # already initialized in this process. Calling initialize_app more
    # than once without giving each app a unique name raises the
    # "default Firebase app already exists" error.
    cred = credentials.Certificate('serviceaccount.json')
    try:
        app = firebase_admin.get_app()
    except ValueError:
        # No app initialized yet; create the default app.
        app = firebase_admin.initialize_app(cred)

    return firestore.client(app)

# -------------------------------
# Fetch sales and station data from Firestore
# -------------------------------
def fetch_data_firestore(db):
    """
    Fetch station metadata from `station_owners` and aggregate sales from
    the top-level `orders` collection. Only orders with `status == 'Completed'`
    are considered. The function sums `totalPrice` or `total_amount` for each
    station referenced in an order's `stationOwnerIds` array.
    """
    stations_ref = db.collection('station_owners')
    stations_data = []
    # Fetch all completed orders from the top-level `orders` collection and
    # aggregate sales per station using the `stationOwnerIds` array field.
    print('Querying orders collection for Completed orders to aggregate sales...')
    orders_ref = db.collection('orders').where('status', '==', 'Completed')
    station_sales = defaultdict(list)

    for order in orders_ref.stream():
        order_dict = order.to_dict()
        raw_value = order_dict.get('totalPrice') or order_dict.get('total_amount') or 0
        try:
            total_value = float(raw_value)
        except (ValueError, TypeError):
            continue

        station_ids = order_dict.get('stationOwnerIds') or order_dict.get('stationOwnerId') or []
        if isinstance(station_ids, str):
            station_ids = [station_ids]
            recs_ref = db.collection("station_recommendations")
            for rec in recommendations:
                    # Add timestamp
                    rec['createdAt'] = datetime.utcnow()

                    # Use district name as the doc ID (overwrite per district)
                    doc_id = rec['district'].replace(" ", "_")  # safer IDs

                    # Add sentiment from the district-level sentiment data
                    district_info = district_sentiments.get(rec['district'])
                    if isinstance(district_info, dict):
                        rec['district_sentiment'] = district_info.get('dominant_sentiment', 'neutral')
                        rec['district_sentiment_score'] = district_info.get('average_sentiment_score', 0)
                        rec['district_sentiment_count'] = district_info.get('sentiment_count', {})
                    else:
                        rec['district_sentiment'] = district_info or 'neutral'

                    recs_ref.document(doc_id).set(rec)
            print(f"Saved {len(recommendations)} recommendations (overwrite mode).")

        stations_data.append({
            'station_id': station_id,
            'district_id': district_id,
            'district_name': district_name,
            'lat': lat,
            'lng': lng,
            'water_type': water_type,
            'total_sales': total_sales
        })
    
    print(f"Fetched {len(stations_data)} stations from Firestore (with aggregated sales from orders).")
    return pd.DataFrame(stations_data)

# -------------------------------
# Fetch Feedback Data and Analyze Sentiment by Station
# -------------------------------
def fetch_and_analyze_feedback_by_station(db):
    feedback_ref = db.collection('feedbacks')
    feedbacks_data = defaultdict(list)

    # Fetch all stations for mapping stationOwnerId to station data
    stations_ref = db.collection('station_owners')
    stations_dict = {}
    
    # Create a dictionary to map stationOwnerId to station data (including district)
    for station in stations_ref.stream():
        station_dict = station.to_dict()
        station_owner_id = station.id  # Station ID is the stationOwnerId
        stations_dict[station_owner_id] = station_dict

        # Fetch feedbacks and group by station
        for feedback in feedback_ref.stream():
            feedback_dict = feedback.to_dict()
            station_owner_id = feedback_dict.get('stationOwnerId')
            comment = feedback_dict.get('comment', '')
            sentiment, sentiment_score = analyze_sentiment(comment)

            # Get the station data using the stationOwnerId
            station_data = stations_dict.get(station_owner_id)

            if station_data:
                # Group feedback sentiments and scores by station
                feedbacks_data[station_owner_id].append({'sentiment': sentiment, 'score': sentiment_score})

        # Calculate the dominant sentiment and average score for each station and update Firestore
        for station_owner_id, feedbacks in feedbacks_data.items():
            sentiment_counts = {'positive': 0, 'neutral': 0, 'negative': 0}
            scores = []
            for feedback in feedbacks:
                sentiment_counts[feedback['sentiment']] += 1
                scores.append(feedback['score'])

            # Determine the dominant sentiment (could be positive, neutral, or negative)
            dominant_sentiment = max(sentiment_counts, key=sentiment_counts.get)
            avg_score = sum(scores) / len(scores) if scores else 0

            # Update the station document with the new sentiment data
            station_ref = db.collection('station_owners').document(station_owner_id)
            station_ref.update({
                'average_sentiment': dominant_sentiment,
                'sentiment_count': sentiment_counts,  # Optional: count of positive/negative/neutral
                'average_sentiment_score': avg_score
            })

        print(f"Processed and updated sentiment for {len(feedbacks_data)} stations.")
        return feedbacks_data

# -------------------------------
# Fetch Feedback Data and Analyze Sentiment by District
# -------------------------------
def fetch_and_analyze_feedback_by_district(db):
    """
    Fetch feedbacks, group by district, and determine the dominant sentiment for each district.
    Returns a dictionary mapping district names to their dominant sentiment.
    """
    feedback_ref = db.collection('feedbacks')
    stations_ref = db.collection('station_owners')
    stations_dict = {}

    # Map stationOwnerId to districtName
    for station in stations_ref.stream():
        station_dict = station.to_dict()
        station_owner_id = station.id
        district_name = station_dict.get('districtName')
        stations_dict[station_owner_id] = district_name

        # Group feedback sentiments and scores by district
        district_feedbacks = defaultdict(list)
        for feedback in feedback_ref.stream():
            feedback_dict = feedback.to_dict()
            station_owner_id = feedback_dict.get('stationOwnerId')
            comment = feedback_dict.get('comment', '')
            sentiment, sentiment_score = analyze_sentiment(comment)
            district_name = stations_dict.get(station_owner_id)
            if district_name:
                district_feedbacks[district_name].append({'sentiment': sentiment, 'score': sentiment_score})

        # Calculate dominant sentiment and average score for each district
        district_sentiments = {}
        for district, feedbacks in district_feedbacks.items():
            sentiment_counts = {'positive': 0, 'neutral': 0, 'negative': 0}
            scores = []
            for feedback in feedbacks:
                sentiment_counts[feedback['sentiment']] += 1
                scores.append(feedback['score'])
            dominant_sentiment = max(sentiment_counts, key=sentiment_counts.get)
            avg_score = sum(scores) / len(scores) if scores else 0
            district_sentiments[district] = {
                'dominant_sentiment': dominant_sentiment,
                'average_sentiment_score': avg_score,
                'sentiment_count': sentiment_counts
            }

        print(f"Processed and determined sentiment for {len(district_sentiments)} districts.")
        return district_sentiments

# -------------------------------
# Dynamic Clustering for Location Recommendations
# -------------------------------
def dynamic_clustering(stations_df):
    """
    Perform DBSCAN clustering on station locations (latitude, longitude).
    """
    locations = stations_df[['lat', 'lng']].values
    clustering = DBSCAN(eps=0.01, min_samples=2, metric='haversine').fit(np.radians(locations))
    stations_df.loc[:, 'cluster'] = clustering.labels_
    return stations_df

def recommend_best_location_for_district(stations_df, district_name, range_radius=50):
    """
    Recommend the best location for a new station within a specific district.
    The recommendation is based on clustering existing stations' locations and sales data.

    :param stations_df: DataFrame containing station data (including latitude, longitude, and sales).
    :param district_name: The name of the district for which to generate the recommendation.
    :param range_radius: The radius (in meters) around the recommended location to consider.
    :return: A dictionary with the recommended location (latitude, longitude) and other details.
    """
    # Filter stations by district
    district_df = stations_df[stations_df['district_name'] == district_name].copy()

    if len(district_df) < 2:
        print(f"Not enough stations in {district_name} to perform clustering.")
        return None

    # Perform clustering on station locations (latitude, longitude)
    district_df = dynamic_clustering(district_df)

    # Group stations by cluster and calculate the total sales for each cluster
    cluster_sales = district_df.groupby('cluster')['total_sales'].sum()

    # Identify the cluster with the highest sales
    highest_density_cluster = cluster_sales.idxmax()

    # Get stations that belong to the highest density cluster
    recommended_stations = district_df[district_df['cluster'] == highest_density_cluster]

    # Calculate weighted average of latitudes and longitudes based on sales
    weighted_lat = np.average(recommended_stations['lat'], weights=recommended_stations['total_sales'])
    weighted_lng = np.average(recommended_stations['lng'], weights=recommended_stations['total_sales'])

    # Get the top-performing station in the highest sales cluster
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
# Main
# -------------------------------
def main(mode="csv", csv_path="synthetic_stations.csv"):
    db = init_firestore()
    
    # Fetch and analyze feedback sentiment by station
    fetch_and_analyze_feedback_by_station(db)

    # Fetch station data and generate recommendations
    stations_df = fetch_data_firestore(db)
    recommendations = []

    for district_name in stations_df['district_name'].dropna().unique():
        rec = recommend_best_location_for_district(stations_df, district_name, range_radius=50)
        if rec:
            recommendations.append(rec)
            print(f"Recommendation for {district_name}: ({rec['lat']}, {rec['lng']})")

    if recommendations:
        # Fetch district sentiments and save the recommendations
        district_sentiments = fetch_and_analyze_feedback_by_district(db)  # Get district sentiments
        for rec in recommendations:
                # Add timestamp
                rec['createdAt'] = datetime.utcnow()

                # Use district name as the doc ID (overwrite per district)
                doc_id = rec['district'].replace(" ", "_")  # safer IDs

                # Add sentiment from the district-level sentiment data
                district_info = district_sentiments.get(rec['district'])
                if isinstance(district_info, dict):
                    rec['district_sentiment'] = district_info.get('dominant_sentiment', 'neutral')
                    rec['district_sentiment_score'] = district_info.get('average_sentiment_score', 0)
                    rec['district_sentiment_count'] = district_info.get('sentiment_count', {})
                else:
                    rec['district_sentiment'] = district_info or 'neutral'

                recs_ref.document(doc_id).set(rec)

        print(f"Saved {len(recommendations)} recommendations (overwrite mode).")
    map_center = [stations_df['lat'].mean(), stations_df['lng'].mean()]
    m = folium.Map(location=map_center, zoom_start=12)

    # Add existing stations as blue markers
    for _, row in stations_df.iterrows():
        folium.Marker(
            location=[row['lat'], row['lng']],
            popup=f"Station: {row['station_id']}<br>District: {row['district_name']}<br>Sales: {row['total_sales']}",
            icon=folium.Icon(color='blue', icon='info-sign')
        ).add_to(m)

    # Add recommended locations as red markers
    for rec in recommendations:
        folium.Marker(
            location=[rec['lat'], rec['lng']],
            popup=f"Recommended Location for {rec['district']}<br>{rec['explanation']}",
            icon=folium.Icon(color='red', icon='star')
        ).add_to(m)

    # Save map to HTML file
    m.save("stations_recommendations_map.html")
    print("Map saved to stations_recommendations_map.html")

# -------------------------------
# Run
# -------------------------------
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["firestore", "csv"], default="csv")
    parser.add_argument("--csv_path", type=str, default="synthetic_stations.csv")
    args = parser.parse_args()

    main(mode=args.mode, csv_path=args.csv_path)
