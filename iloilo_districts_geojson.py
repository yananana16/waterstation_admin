#!/usr/bin/env python3
"""
Generate GeoJSON for Iloilo City's 7 districts by querying OpenStreetMap (Nominatim).

Districts covered:
- City Proper
- Jaro
- La Paz
- Lapuz
- Mandurriao
- Molo
- Arevalo

Output:
- Writes: iloilo_city_7_districts.geojson
- Prints the same GeoJSON to stdout

Requirements: requests (stdlib json/time used)
    pip install requests
"""

import json
import time
import sys
from typing import Dict, Any, List, Optional
import requests

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

# IMPORTANT: Put a valid contact here to comply with Nominatim usage policy.
USER_AGENT = "IloiloDistrictsGeoJSON/1.0 (contact: youremail@example.com)"

# The seven districts of Iloilo City
DISTRICTS = [
    "City Proper",
    "Jaro",
    "La Paz",
    "Lapuz",
    "Mandurriao",
    "Molo",
    "Arevalo",
]

# Helpful aliases to improve matching robustness (left: canonical, right: search variants)
ALIASES: Dict[str, List[str]] = {
    "La Paz": ["La Paz", "LaPaz", "La-Paz"],
    "Lapuz": ["Lapuz"],
    "City Proper": ["City Proper", "Iloilo City Proper", "Iloilo City Proper District"],
    "Arevalo": ["Arevalo", "Villa Arevalo", "Villa de Arevalo", "Villa-Arevalo"],
    "Mandurriao": ["Mandurriao"],
    "Molo": ["Molo"],
    "Jaro": ["Jaro"],
}

# Extra filters to reduce false positives
CITY_FILTERS = [
    "Iloilo City",
    "Iloilo, Western Visayas",
    "Iloilo City, Iloilo",
    "Western Visayas",
    "Philippines",
]

def nominatim_search(query: str, extra_params: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    """Query Nominatim for a string and return JSON results."""
    params = {
        "q": query,
        "format": "jsonv2",
        "polygon_geojson": 1,  # return polygon/multipolygon if available
        "addressdetails": 1,
        "limit": 10,
    }
    if extra_params:
        params.update(extra_params)

    headers = {
        "User-Agent": USER_AGENT
    }

    resp = requests.get(NOMINATIM_URL, params=params, headers=headers, timeout=30)
    resp.raise_for_status()
    return resp.json()  # type: ignore[no-any-return]


def likely_in_iloilo_city(item: Dict[str, Any]) -> bool:
    """Heuristic to ensure result belongs to Iloilo City, Philippines."""
    disp = (item.get("display_name") or "").lower()
    # Must contain "iloilo city" and "philippines" to be safe
    if "iloilo city" in disp and "philippines" in disp:
        return True

    # Fall back to address fields
    addr = item.get("address") or {}
    city_like = (addr.get("city") or addr.get("town") or addr.get("municipality") or "").lower()
    state = (addr.get("state") or addr.get("province") or "").lower()
    country = (addr.get("country") or "").lower()

    if "iloilo city" in city_like and "philippines" in country:
        return True
    if "iloilo" in state and "philippines" in country and ("iloilo city" in disp):
        return True

    # Final soft check using filters in display_name
    return any(s.lower() in disp for s in [c for c in CITY_FILTERS]) and ("philippines" in disp)


def score_candidate(item: Dict[str, Any], district_name: str) -> int:
    """
    Rank candidates: prefer boundaries or suburbs within Iloilo City,
    with polygon geometry available.
    Higher score is better.
    """
    score = 0

    cls = item.get("class")
    typ = item.get("type")
    geo = item.get("geojson")

    # Prefer boundary / administrative or place=suburb/neighbourhood
    if cls == "boundary":
        score += 5
    if cls == "place" and typ in {"suburb", "neighbourhood", "quarter"}:
        score += 3

    # Must be inside Iloilo City
    if likely_in_iloilo_city(item):
        score += 4

    # Has polygon geometry
    if isinstance(geo, dict) and geo.get("type") in {"Polygon", "MultiPolygon"}:
        score += 4

    # Name closeness
    name = (item.get("name") or "").lower()
    if name == district_name.lower():
        score += 3
    elif district_name.lower() in name:
        score += 1

    # Admin level preference (lower is larger area; districts often 9–10; this is heuristic)
    admin_level = (item.get("extratags") or {}).get("admin_level")
    if admin_level:
        try:
            al = int(admin_level)
            if 8 <= al <= 11:
                score += 1
        except ValueError:
            pass

    return score


def pick_best_result(results: List[Dict[str, Any]], district_name: str) -> Optional[Dict[str, Any]]:
    """Choose the best Nominatim result for the district."""
    if not results:
        return None
    ranked = sorted(results, key=lambda x: score_candidate(x, district_name), reverse=True)
    return ranked[0]


def fetch_district_geojson(district_name: str) -> Optional[Dict[str, Any]]:
    """
    Try multiple query patterns to retrieve a polygon/multipolygon GeoJSON
    for a given district. Returns a GeoJSON Feature or None.
    """
    variants = ALIASES.get(district_name, [district_name])
    queries = []

    # Build queries that bias to Iloilo City
    for v in variants:
        queries.extend([
            f"{v}, Iloilo City, Iloilo, Philippines",
            f"{v}, Iloilo City, Western Visayas, Philippines",
            f"{v} District, Iloilo City, Philippines",
            f"{v} Iloilo City Philippines",
        ])

    for q in queries:
        try:
            results = nominatim_search(q)
        except Exception as e:
            print(f"[WARN] Query failed for '{q}': {e}", file=sys.stderr)
            time.sleep(1)
            continue

        if not results:
            time.sleep(1)
            continue

        best = pick_best_result(results, district_name)
        if not best:
            time.sleep(1)
            continue

        geo = best.get("geojson")
        if isinstance(geo, dict) and geo.get("type") in {"Polygon", "MultiPolygon"}:
            # Construct a clean Feature
            props = {
                "name": district_name,
                "osm_name": best.get("name"),
                "display_name": best.get("display_name"),
                "class": best.get("class"),
                "type": best.get("type"),
                "importance": best.get("importance"),
                "osm_id": best.get("osm_id"),
                "osm_type": best.get("osm_type"),
                "source": "OpenStreetMap Nominatim",
            }
            feature = {
                "type": "Feature",
                "properties": props,
                "geometry": geo,
            }
            return feature

        time.sleep(1)

    return None


def main():
    features: List[Dict[str, Any]] = []
    missing: List[str] = []

    print("Fetching Iloilo City district polygons from OpenStreetMap…", file=sys.stderr)

    for name in DISTRICTS:
        print(f"  - {name} …", file=sys.stderr)
        feat = fetch_district_geojson(name)
        if feat is not None:
            features.append(feat)
            print(f"    ✓ found geometry", file=sys.stderr)
        else:
            missing.append(name)
            print(f"    ✗ not found (will be omitted)", file=sys.stderr)
        # Be kind to Nominatim
        time.sleep(1)

    collection = {
        "type": "FeatureCollection",
        "name": "Iloilo City Districts",
        "crs": {
            "type": "name",
            "properties": {"name": "urn:ogc:def:crs:OGC:1.3:CRS84"}
        },
        "features": features
    }

    out_path = "iloilo_city_7_districts.geojson"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(collection, f, ensure_ascii=False, separators=(",", ":"), indent=2)

    # Also print to stdout
    print(json.dumps(collection, ensure_ascii=False, indent=2))

    # Summary to stderr
    print("\nSummary:", file=sys.stderr)
    print(f"  Saved: {out_path}", file=sys.stderr)
    if missing:
        print(f"  Missing districts (not returned by Nominatim): {', '.join(missing)}", file=sys.stderr)
        print("  Tip: run again later or adjust aliases/queries; OSM coverage can vary.", file=sys.stderr)
    else:
        print("  All 7 districts found.", file=sys.stderr)


if __name__ == "__main__":
    main()
