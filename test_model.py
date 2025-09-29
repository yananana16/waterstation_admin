#!/usr/bin/env python3
# test_model.py
# Evaluate clustering quality and recommendation accuracy.

import os
import logging
import numpy as np
import pandas as pd
from sklearn.metrics import silhouette_score, davies_bouldin_score
from sklearn.model_selection import train_test_split

from ai_analytics import (
    get_db,
    fetch_sales,
    fetch_stations,
    build_station_joined_sales,
    recommend_new_locations,
    ASIA_MANILA
)

# ----------------------------
# Logging setup
# ----------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()]
)

# ----------------------------
# Cluster Quality Evaluation
# ----------------------------
def evaluate_clusters(df_joined, stations_df):
    logging.info("Running recommendation model for evaluation…")
    recs = recommend_new_locations(df_joined, stations_df)
    if not recs:
        logging.warning("No recommendations generated. Skipping evaluation.")
        return None

    logging.info(f"Generated {len(recs)} recommendations.")
    recs_df = pd.DataFrame([r.__dict__ for r in recs])

    # Cluster quality metrics (global)
    try:
        # use only demand points for metrics
        pts = df_joined[["customer_lat", "customer_lng"]].dropna().values
        if len(pts) > 2:
            # dummy labels: assign each point to nearest recommendation
            labels = []
            for lat, lng in pts:
                dists = np.sqrt((recs_df["lat"] - lat) ** 2 + (recs_df["lng"] - lng) ** 2)
                labels.append(np.argmin(dists))
            sil = silhouette_score(pts, labels)
            dbi = davies_bouldin_score(pts, labels)
            logging.info(f"Silhouette Score: {sil:.3f}")
            logging.info(f"Davies–Bouldin Index: {dbi:.3f}")
        else:
            logging.warning("Not enough points for global cluster metrics.")
    except Exception as e:
        logging.error(f"Cluster evaluation failed: {e}", exc_info=True)

    return recs_df

# ----------------------------
# Backtesting (hold-out validation)
# ----------------------------
def backtest(df_joined, stations_df, test_size=0.2):
    logging.info(f"Backtesting with {test_size*100:.0f}% holdout customers…")
    train_df, test_df = train_test_split(df_joined, test_size=test_size, random_state=42)

    recs = recommend_new_locations(train_df, stations_df)
    if not recs:
        logging.warning("No recommendations generated in backtest.")
        return None

    recs_df = pd.DataFrame([r.__dict__ for r in recs])

    # Check coverage: how many test customers fall near a recommended location
    cover_radius_m = 500  # meters
    covered = 0
    for _, row in test_df.iterrows():
        lat, lng = row["customer_lat"], row["customer_lng"]
        if pd.isna(lat) or pd.isna(lng):
            continue
        dists = np.sqrt((recs_df["lat"] - lat) ** 2 + (recs_df["lng"] - lng) ** 2)
        if dists.min() * 111000 < cover_radius_m:  # rough lat/lng→meters
            covered += 1

    coverage = covered / len(test_df) if len(test_df) > 0 else 0
    logging.info(f"Backtest coverage within {cover_radius_m}m: {coverage:.2%}")
    return coverage

# ----------------------------
# MAIN
# ----------------------------
def main():
    logging.info("Connecting to Firestore…")
    db = get_db()

    logging.info("Fetching stations & sales…")
    stations_df = fetch_stations(db)
    sales_df = fetch_sales(db)

    if sales_df.empty or stations_df.empty:
        logging.error("No data available for testing.")
        return

    logging.info("Building joined dataset…")
    joined = build_station_joined_sales(sales_df, stations_df)
    joined = joined.dropna(subset=["stationOwnerId", "waterType"])

    logging.info(f"Joined rows: {len(joined)}")

    # Evaluate clusters
    evaluate_clusters(joined, stations_df)

    # Run backtesting
    backtest(joined, stations_df, test_size=0.2)


if __name__ == "__main__":
    main()
