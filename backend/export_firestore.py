import json
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Helper function to serialize special Firestore data types
def firestore_to_json(obj):
    if isinstance(obj, datetime):
        return obj.isoformat()
    # Handle Firestore GeoPoint
    if hasattr(obj, 'latitude') and hasattr(obj, 'longitude'):
        return {"latitude": obj.latitude, "longitude": obj.longitude}
    # Handle Firestore DocumentReference
    if hasattr(obj, 'path'):
        return {"reference": obj.path}
    # Fallback for other non-serializable objects
    return str(obj)

# Initialize Firebase using the existing service account key in the backend
cred = credentials.Certificate("firebase_key.json")
try:
    firebase_admin.initialize_app(cred)
except ValueError:
    pass # App already initialized

db = firestore.client()

def export_data():
    export_data = {}
    collections = db.collections()
    
    for collection in collections:
        collection_name = collection.id
        export_data[collection_name] = {}
        print(f"Exporting collection: {collection_name}...")
        
        docs = collection.stream()
        for doc in docs:
            export_data[collection_name][doc.id] = doc.to_dict()
            
    with open("firestore_export.json", "w") as f:
        json.dump(export_data, f, default=firestore_to_json, indent=2)
        
    print("\n✅ Export complete! Your Firebase data is in 'firestore_export.json'")

if __name__ == "__main__":
    export_data()
