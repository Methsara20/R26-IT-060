"""
backend/firebase_service.py
Same Firestore-only logic as shared/firebase_client.py in the Streamlit app,
but without any Streamlit dependency, so the FastAPI backend can run as a
fully independent service. Reads the exact same collections, so data saved
by either app is visible to both.
"""

import pandas as pd
import io
import os

FIREBASE_KEY_PATH = "firebase-key.json"
CHUNKS_COLLECTION = "skyhigh_csv_chunks"
HISTORY_COLLECTION = "skyhigh_upload_history"

_firebase_app = None
_db = None


def init_firebase():
    global _firebase_app, _db
    if _firebase_app is not None:
        return True
    if not os.path.exists(FIREBASE_KEY_PATH):
        return False

    import firebase_admin
    from firebase_admin import credentials, firestore

    try:
        cred = credentials.Certificate(FIREBASE_KEY_PATH)
        _firebase_app = firebase_admin.initialize_app(cred)
        _db = firestore.client()
        return True
    except ValueError:
        _firebase_app = firebase_admin.get_app()
        _db = firestore.client()
        return True
    except Exception as e:
        print(f"Firebase connection failed: {e}")
        return False


def load_latest_csv(file_type: str):
    """Returns a DataFrame of the most recent upload of a given type, or None."""
    if not init_firebase():
        return None
    try:
        docs = (_db.collection(HISTORY_COLLECTION)
                .where("file_type", "==", file_type)
                .order_by("uploaded_at", direction="DESCENDING")
                .limit(1)
                .stream())
        latest = next(docs, None)
        if latest is None:
            return None

        record = latest.to_dict()
        upload_id = record["upload_id"]
        total_chunks = record["total_chunks"]

        chunk_texts = [None] * total_chunks
        chunk_docs = (_db.collection(CHUNKS_COLLECTION)
                      .where("upload_id", "==", upload_id)
                      .stream())
        for doc in chunk_docs:
            data = doc.to_dict()
            chunk_texts[data["chunk_index"]] = data["content"]

        full_csv_text = "".join(chunk_texts)
        return pd.read_csv(io.StringIO(full_csv_text))
    except Exception as e:
        print(f"Could not load {file_type}: {e}")
        return None


def get_upload_history(limit: int = 20):
    if not init_firebase():
        return []
    try:
        docs = (_db.collection(HISTORY_COLLECTION)
                .order_by("uploaded_at", direction="DESCENDING")
                .limit(limit)
                .stream())
        return [d.to_dict() for d in docs]
    except Exception:
        return []