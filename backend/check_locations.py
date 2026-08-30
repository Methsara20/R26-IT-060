"""
check_locations.py
Counts unique store locations (store_id values) in the shared Inventory
component's overstock data. Run this from backend, where
shared-firebase-key.json already lives.

Run:
    python check_locations.py
"""
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("shared-firebase-key.json")
app = firebase_admin.initialize_app(cred, name="check_locations_temp")
db = firestore.client(app=app)

doc = db.collection("alert_items").document("overstock").get()

if not doc.exists:
    print("No overstock document found.")
else:
    data = doc.to_dict()
    items = data.get("items", [])
    store_ids = set(item.get("store_id") for item in items if item.get("store_id"))

    print(f"Total overstock items: {len(items)}")
    print(f"Unique store locations: {len(store_ids)}")
    print("Store IDs found:")
    for sid in sorted(store_ids):
        count = sum(1 for i in items if i.get("store_id") == sid)
        print(f"  {sid}: {count} item(s)")

firebase_admin.delete_app(app)
