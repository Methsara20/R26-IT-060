import firebase_admin
from firebase_admin import credentials, firestore

import os
import json

db = None

# Initialize only once
if not firebase_admin._apps:
    try:
        if os.environ.get("FIREBASE_CREDENTIALS"):
            cred_dict = json.loads(os.environ.get("FIREBASE_CREDENTIALS"))
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
        else:
            key_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "firebase_key.json")
            if not os.path.exists(key_path):
                key_path = "firebase_key.json"
            if os.path.exists(key_path):
                cred = credentials.Certificate(key_path)
                firebase_admin.initialize_app(cred)
            else:
                print("WARNING: firebase_key.json not found and FIREBASE_CREDENTIALS env var missing.")
    except Exception as e:
        print(f"WARNING: Firebase Admin initialization error: {e}")

try:
    if firebase_admin._apps:
        db = firestore.client()
except Exception as e:
    print(f"WARNING: Firestore client initialization error: {e}")