import os
import random
from datetime import datetime, timedelta, timezone
import firebase_admin
from firebase_admin import credentials, firestore
from math import radians, cos, sin, asin, sqrt
from collections import defaultdict

# ---------- Firebase init ----------
KEY_PATH = "serviceAccountKey.json"   # adjust if needed
cred = credentials.Certificate(KEY_PATH)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

# ---------- helpers ----------
def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    return 2 * R * asin(sqrt(a))

def _get(d, *keys, default=None):
    cur = d
    for k in keys:
        if not isinstance(cur, dict) or k not in cur:
            return default
        cur = cur[k]
    return cur

# ---------- fetch Firestore data ----------
def fetch_stations_by_district():
    """Group stations by districtName."""
    districts = defaultdict(list)
    for station_doc in db.collection("station_owners").stream():
        station_id = station_doc.id
        sdata = station_doc.to_dict() or {}

        district = sdata.get("districtName", "Unknown")

        loc = sdata.get("location") or {}
        lat = loc.get("latitude") or loc.get("lat") or (loc.get("map", {}) or {}).get("lat")
        lng = loc.get("longitude") or loc.get("lng") or (loc.get("map", {}) or {}).get("lng")
        if not (lat and lng):
            continue

        for pdoc in station_doc.reference.collection("products").stream():
            pdata = pdoc.to_dict() or {}
            if not pdata.get("waterType"):
                continue

            refill_price = _get(pdata, "offers", "refillWater", default=pdata.get("refillWater", 0)) or 0
            round_price  = _get(pdata, "offers", "round", default=pdata.get("round", 25)) or 25
            slim_price   = _get(pdata, "offers", "slim", default=pdata.get("slim", 25)) or 25
            delivery_fee = _get(pdata, "delivery", "price", default=0) or 0
            allow_borrow = pdata.get("allowBorrow", False)
            water_type   = pdata.get("waterType", "Water")

            station_info = {
                "stationOwnerId": station_id,
                "productId": pdoc.id,
                "waterType": water_type,
                "refillPrice": float(refill_price),
                "roundPrice": float(round_price),
                "slimPrice": float(slim_price),
                "deliveryFee": float(delivery_fee),
                "allowBorrow": bool(allow_borrow),
                "lat": float(lat),
                "lng": float(lng),
                "name": f"{water_type} - Refill Water"
            }
            districts[district].append(station_info)
            break  # one product per station
    return districts

def fetch_customers():
    customers = []
    for cust_doc in db.collection("customers").stream():
        cdata = cust_doc.to_dict() or {}
        for a in cust_doc.reference.collection("address").limit(1).stream():
            ad = a.to_dict() or {}
            if ad.get("latitude") is None or ad.get("longitude") is None:
                continue
            customers.append({
                "customerId": cust_doc.id,
                "email": cdata.get("email", ""),
                "lat": float(ad["latitude"]),
                "lng": float(ad["longitude"]),
                "address": ad.get("address", ""),
                "addressId": a.id
            })
            break
    return customers

# ---------- generator ----------
def generate_orders_by_district(orders_per_district=10, empty_container_prob=0.2):
    stations_by_district = fetch_stations_by_district()
    customers = fetch_customers()

    if not stations_by_district or not customers:
        print("⚠️ No stations or customers found.")
        return []

    orders = []
    for district, stations in stations_by_district.items():
        if not stations:
            continue

        print(f"\n📍 Generating {orders_per_district} orders for district: {district}")

        for _ in range(orders_per_district):
            customer = random.choice(customers)
            station  = random.choice(stations)

            createdAt = datetime.now(timezone.utc) - timedelta(
                days=random.randint(0, 59),
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59)
            )
            fulfill_minutes = random.randint(5, 60)
            updatedAt = createdAt + timedelta(minutes=fulfill_minutes)

            qty = random.randint(1, 3)
            round_count = random.randint(0, qty)
            slim_count = qty - round_count
            borrow = station["allowBorrow"] and (random.random() < 0.15)

            refill_subtotal = station["refillPrice"] * qty

            container_items = []
            container_total = 0.0
            if random.random() < empty_container_prob:
                buy_round = random.randint(0, 2)
                buy_slim  = random.randint(0, 2 - buy_round)
                if buy_round > 0:
                    price = station["roundPrice"]
                    container_total += price * buy_round
                    container_items.append({
                        "name": "Empty Container - Round",
                        "price": price,
                        "productId": None,
                        "quantity": buy_round,
                        "raw_line_item": {
                            "amount": int(price * 100),
                            "currency": "PHP",
                            "name": "Empty Container - Round",
                            "stationOwnerId": station["stationOwnerId"],
                        },
                        "stationOwnerId": station["stationOwnerId"],
                        "stationOwnerIds": [station["stationOwnerId"]],
                    })
                if buy_slim > 0:
                    price = station["slimPrice"]
                    container_total += price * buy_slim
                    container_items.append({
                        "name": "Empty Container - Slim",
                        "price": price,
                        "productId": None,
                        "quantity": buy_slim,
                        "raw_line_item": {
                            "amount": int(price * 100),
                            "currency": "PHP",
                            "name": "Empty Container - Slim",
                            "stationOwnerId": station["stationOwnerId"],
                        },
                        "stationOwnerId": station["stationOwnerId"],
                        "stationOwnerIds": [station["stationOwnerId"]],
                    })

            delivery_fee = station["deliveryFee"] or 55
            products_subtotal = refill_subtotal + container_total
            total_price = products_subtotal + delivery_fee

            distance_m = haversine(customer["lat"], customer["lng"], station["lat"], station["lng"])
            order_id = f"ORD-{int(datetime.now().timestamp()*1000)}-{customer['customerId'][:5]}"

            items = [
                {
                    "name": station["name"],
                    "price": station["refillPrice"],
                    "productId": station["productId"],
                    "quantity": qty,
                    "raw_line_item": {
                        "amount": int(station["refillPrice"] * 100),
                        "currency": "PHP",
                        "name": station["name"],
                        "productId": station["productId"],
                        "quantity": qty,
                        "stationOwnerId": station["stationOwnerId"],
                    },
                    "containers": {
                        "borrow": borrow,
                        "round": round_count,
                        "slim": slim_count
                    },
                    "stationOwnerId": station["stationOwnerId"],
                    "stationOwnerIds": [station["stationOwnerId"]],
                }
            ]
            items.extend(container_items)
            items.append({
                "name": "Delivery Fee",
                "price": delivery_fee,
                "productId": None,
                "quantity": 1,
                "raw_line_item": {
                    "amount": int(delivery_fee * 100),
                    "currency": "PHP",
                    "name": "Delivery Fee",
                    "stationOwnerId": station["stationOwnerId"],
                },
                "stationOwnerId": station["stationOwnerId"],
                "stationOwnerIds": [station["stationOwnerId"]],
            })

            order = {
                "createdAt": createdAt,
                "updatedAt": updatedAt,
                "timestamp": createdAt,
                "status": "Completed",
                "orderId": order_id,
                "order_type": "delivery",
                "payment_channel": random.choice(["cod", "online"]),
                "payment_status": "paid",
                "paymongo_session_id": "SIMULATED",

                "customerId": customer["customerId"],
                "customer_coords": {"lat": customer["lat"], "lng": customer["lng"]},

                "deliveryFees": {station["stationOwnerId"]: delivery_fee},
                "deliveryTotal": delivery_fee,
                "fulfillment_time_minutes": fulfill_minutes,

                "items": items,

                "stationOwnerId": station["stationOwnerId"],
                "stationOwnerIds": [station["stationOwnerId"]],

                "perStationMeta": {
                    station["stationOwnerId"]: {
                        "delivery_distance_m": distance_m,
                        "productsTotal": total_price,
                        "promo_code": None
                    }
                },

                "shippingAddress": {
                    "id": customer["addressId"],
                    "address": customer["address"],
                    "latitude": customer["lat"],
                    "longitude": customer["lng"],
                    "stationOwnerId": station["stationOwnerId"],
                    "stationOwnerIds": [station["stationOwnerId"]],
                    "timestamp": createdAt
                },

                "totalPrice": total_price,
                "total_amount": total_price,
            }

            db.collection("orders").document(order_id).set(order)
            orders.append(order)
            print(f"✅ {district}: Inserted order {order_id} → ₱{total_price:.0f}")

    return orders

if __name__ == "__main__":
    # Example: 10 orders per district
    generate_orders_by_district(orders_per_district=1000)
