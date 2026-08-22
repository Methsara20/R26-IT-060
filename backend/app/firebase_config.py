import firebase_admin
from firebase_admin import credentials, firestore

import os
import json

# Initialize only once
if not firebase_admin._apps:
    if os.environ.get("FIREBASE_CREDENTIALS"):
        cred_dict = json.loads(os.environ.get("FIREBASE_CREDENTIALS"))
        cred = credentials.Certificate(cred_dict)
    else:
        cred = credentials.Certificate("firebase_key.json")
    firebase_admin.initialize_app(cred)

db = firestore.client()