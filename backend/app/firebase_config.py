import firebase_admin
from firebase_admin import credentials, firestore

import os
import json
from dotenv import load_dotenv

# Ensure .env is loaded
load_dotenv(dotenv_path=".env")

# Initialize only once
if not firebase_admin._apps:
    if os.environ.get("FIREBASE_CREDENTIALS"):
        cred_dict = json.loads(os.environ.get("FIREBASE_CREDENTIALS"))
        cred = credentials.Certificate(cred_dict)
    else:
        cred = credentials.Certificate("app/config/firebase_key.json") if os.path.exists("app/config/firebase_key.json") else credentials.Certificate("firebase_key.json")
    try:
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Warning: Firebase init failed - {e}")

db_type = os.environ.get("DB_TYPE", "firebase").lower()

if db_type == "mongodb":
    from app.mongo_client import MongoFirestoreClient
    mongo_uri = os.environ.get("MONGODB_URI")
    db = MongoFirestoreClient(mongo_uri)
    print("Database Initialized: MONGODB")
else:
    db = firestore.client()
    print("Database Initialized: FIREBASE")