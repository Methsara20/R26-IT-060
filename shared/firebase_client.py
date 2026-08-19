"""
shared/firebase_client.py
Stores uploaded SkyHigh CSVs directly in Firestore (chunked, since Firestore
documents are capped at ~1MB each) instead of Cloud Storage — this avoids
needing the paid Blaze plan, since Firestore works on the free Spark plan.

Collections used (new, clearly namespaced so nothing here touches any other
teammate's collections like inventory_current, alert_items, etc.):
  skyhigh_csv_chunks     -> individual CSV chunks
  skyhigh_upload_history -> one record per upload (filename, type, timestamp, row_count)

Setup required (one-time, per machine running the app):
1. Download the service account key from Firebase Console:
   Project Settings -> Service accounts -> Generate new private key
2. Save it in the project root as `firebase-key.json`
3. Make sure `firebase-key.json` is in .gitignore — never commit it.
"""

import streamlit as st
import pandas as pd
import io
import os
import math
import uuid
from datetime import datetime

FIREBASE_KEY_PATH = "firebase-key.json"
CHUNKS_COLLECTION = "skyhigh_csv_chunks"
HISTORY_COLLECTION = "skyhigh_upload_history"
CHUNK_SIZE = 900_000  # bytes, safely under Firestore's ~1MB document limit

_firebase_app = None
_db = None


def init_firebase():
    """Initializes the Firebase app once per session. Returns True if ready,
    False (with a friendly warning shown) if the key file is missing."""
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
        st.error(f"Firebase connection failed: {e}")
        return False


def save_csv_to_firebase(df, file_type):
    """
    Saves a cleaned dataframe to Firestore as chunked text documents, and
    logs the upload event. file_type should be one of:
    'campaigns', 'customers', 'transactions'.
    Returns True on success, False on failure (with a message shown).
    """
    if not init_firebase():
        st.warning("⚠️ Firebase not connected — data saved for this session only. "
                    "Add firebase-key.json to persist uploads.")
        return False

    try:
        csv_text = df.to_csv(index=False)
        csv_bytes = csv_text.encode("utf-8")
        total_chunks = math.ceil(len(csv_bytes) / CHUNK_SIZE)
        upload_id = f"{file_type}_{uuid.uuid4().hex[:8]}"
        timestamp = datetime.now().isoformat()

        for i in range(total_chunks):
            start = i * CHUNK_SIZE
            end = start + CHUNK_SIZE
            chunk_text = csv_bytes[start:end].decode("utf-8", errors="ignore")
            doc_id = f"{upload_id}_chunk{i}"
            _db.collection(CHUNKS_COLLECTION).document(doc_id).set({
                "upload_id": upload_id,
                "file_type": file_type,
                "chunk_index": i,
                "total_chunks": total_chunks,
                "content": chunk_text,
            })

        _db.collection(HISTORY_COLLECTION).add({
            "file_type": file_type,
            "upload_id": upload_id,
            "uploaded_at": timestamp,
            "row_count": len(df),
            "total_chunks": total_chunks,
        })

        return True
    except Exception as e:
        st.warning(f"⚠️ Could not save to Firebase: {e}. Data is still available for this session.")
        return False


def load_latest_csv_from_firebase(file_type):
    """
    Loads the most recently uploaded CSV of a given type from Firestore.
    Returns a DataFrame, or None if nothing found / Firebase not connected.
    """
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
    except Exception:
        return None


def get_upload_history(limit=20):
    """Returns a list of recent upload events (dicts) for display in the UI."""
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