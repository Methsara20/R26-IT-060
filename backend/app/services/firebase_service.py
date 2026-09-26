def get_db():
    from app.firebase_config import db
    return db


def get_collection(collection_name: str):
    database = get_db()
    if database is None:
        return None
    return database.collection(collection_name)


def get_all_documents(collection_name: str):
    try:
        col = get_collection(collection_name)
        if col is None:
            return []
        
        docs = col.stream()
        data = []
        for doc in docs:
            item = doc.to_dict()
            item["id"] = doc.id
            data.append(item)

        return data
    except Exception as e:
        print(f"[FirebaseService] Exception fetching collection '{collection_name}': {e}")
        return []

def get_paginated_documents(collection_name: str, limit: int, offset: int, filters: list = None):
    try:
        col = get_collection(collection_name)
        if col is None:
            return []
        
        query = col
        if filters:
            for f in filters:
                query = query.where(f["field"], f["op"], f["value"])
                
        if offset > 0:
            query = query.offset(offset)
        query = query.limit(limit)
        
        docs = query.stream()
        data = []
        for doc in docs:
            item = doc.to_dict()
            item["id"] = doc.id
            data.append(item)

        return data
    except Exception as e:
        print(f"[FirebaseService] Exception paginating collection '{collection_name}': {e}")
        return []


def get_document_by_id(collection_name: str, document_id: str):
    try:
        col = get_collection(collection_name)
        if col is None:
            return None

        doc = col.document(document_id).get()

        if not doc.exists:
            return None

        item = doc.to_dict()
        item["id"] = doc.id
        return item
    except Exception as e:
        print(f"[FirebaseService] Exception fetching document '{document_id}' in '{collection_name}': {e}")
        return None


def create_or_update_document(
    collection_name: str,
    document_id: str,
    data: dict,
    merge: bool = True
):
    col = get_collection(collection_name)
    if col is None:
        raise RuntimeError("Firestore DB is not connected.")

    col.document(document_id).set(
        data,
        merge=merge
    )

    return {
        "message": "Document saved successfully",
        "collection": collection_name,
        "document_id": document_id
    }


def update_document(collection_name: str, document_id: str, data: dict):
    col = get_collection(collection_name)
    if col is None:
        raise RuntimeError("Firestore DB is not connected.")

    doc_ref = col.document(document_id)

    if not doc_ref.get().exists:
        return None

    doc_ref.update(data)

    return {
        "message": "Document updated successfully",
        "collection": collection_name,
        "document_id": document_id
    }


def delete_document(collection_name: str, document_id: str):
    col = get_collection(collection_name)
    if col is None:
        raise RuntimeError("Firestore DB is not connected.")

    doc_ref = col.document(document_id)

    if not doc_ref.get().exists:
        return None

    doc_ref.delete()

    return {
        "message": "Document deleted successfully",
        "collection": collection_name,
        "document_id": document_id
    }



# --- Appended from backend2 ---

import pandas as pd
import io
import uuid
from datetime import datetime

CHUNKS_COLLECTION = "skyhigh_csv_chunks"
HISTORY_COLLECTION = "skyhigh_upload_history"
NOTES_COLLECTION = "skyhigh_calendar_notes"


def _reassemble_chunks_text(db, upload_id: str, total_chunks: int) -> str:
    """Reassembles the raw CSV text for a given upload_id from its chunks."""
    chunk_texts = [None] * total_chunks
    chunk_docs = (db.collection(CHUNKS_COLLECTION)
                  .where("upload_id", "==", upload_id)
                  .stream())
    for doc in chunk_docs:
        data = doc.to_dict()
        chunk_texts[data["chunk_index"]] = data["content"]
    return "".join(chunk_texts)


def load_latest_csv(file_type: str):
    """Returns a DataFrame of the most recent upload of a given type, or None."""
    db = get_db()
    if not db:
        return None
    try:
        docs = (db.collection(HISTORY_COLLECTION)
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
        full_csv_text = _reassemble_chunks_text(db, upload_id, total_chunks)
        return pd.read_csv(io.StringIO(full_csv_text))
    except Exception as e:
        print(f"Could not load {file_type}: {e}")
        return None


def get_upload_history(limit: int = 20):
    db = get_db()
    if not db:
        return []
    try:
        docs = (db.collection(HISTORY_COLLECTION)
                .order_by("uploaded_at", direction="DESCENDING")
                .limit(limit)
                .stream())
        return [d.to_dict() for d in docs]
    except Exception:
        return []


def get_csv_download(upload_id: str):
    """
    Returns (file_type, raw_csv_text) for a specific past upload, or
    (None, None) if it doesn't exist. Returns the raw text exactly as
    stored — no pandas round-trip, so formatting is preserved.
    """
    db = get_db()
    if not db:
        return None, None
    try:
        doc = db.collection(HISTORY_COLLECTION).document(upload_id).get()
        if not doc.exists:
            return None, None
        record = doc.to_dict()
        csv_text = _reassemble_chunks_text(db, upload_id, record["total_chunks"])
        return record.get("file_type"), csv_text
    except Exception as e:
        print(f"Could not download upload {upload_id}: {e}")
        return None, None


def delete_upload(upload_id: str) -> bool:
    """
    Deletes a specific upload entirely — its history record AND every
    associated chunk document, so nothing orphaned is left behind.
    """
    db = get_db()
    if not db:
        return False
    try:
        chunk_docs = list(db.collection(CHUNKS_COLLECTION).where("upload_id", "==", upload_id).stream())
        batch = db.batch()
        for doc in chunk_docs:
            batch.delete(doc.reference)
        batch.delete(db.collection(HISTORY_COLLECTION).document(upload_id))
        batch.commit()
        return True
    except Exception as e:
        print(f"Could not delete upload {upload_id}: {e}")
        return False


def save_csv_to_firebase(df, file_type: str, chunk_size_lines: int = 5000):
    db = get_db()
    if not db:
        return False, "Firebase not connected."
    try:
        upload_id = str(uuid.uuid4())
        csv_text = df.to_csv(index=False)
        lines = csv_text.split('\n')
        chunks = []
        for i in range(0, len(lines), chunk_size_lines):
            chunk = '\n'.join(lines[i:i + chunk_size_lines])
            chunks.append(chunk)
        batch = db.batch()
        for i, chunk in enumerate(chunks):
            doc_ref = db.collection(CHUNKS_COLLECTION).document(f"{upload_id}_{i}")
            batch.set(doc_ref, {
                "upload_id": upload_id,
                "chunk_index": i,
                "content": chunk
            })

        hist_ref = db.collection(HISTORY_COLLECTION).document(upload_id)
        batch.set(hist_ref, {
            "upload_id": upload_id,
            "file_type": file_type,
            "uploaded_at": datetime.utcnow().isoformat(),
            "total_chunks": len(chunks),
            "total_rows": len(df)
        })

        batch.commit()
        return True, None
    except Exception as e:
        return False, str(e)


def _find_date_column(df):
    """Looks for a plausible date column in the campaigns CSV."""
    candidates = ["date", "campaign_date", "sent_date", "send_date", "created_at"]
    for c in candidates:
        if c in df.columns:
            return c
    return None


def get_campaign_counts_by_day(year: int, month: int):
    """Returns {day: count} of campaigns sent in the given month."""
    df = load_latest_csv("campaigns")
    if df is None:
        return {}
    date_col = _find_date_column(df)
    if date_col is None:
        return {}
    try:
        dates = pd.to_datetime(df[date_col], errors="coerce")
        mask = (dates.dt.year == year) & (dates.dt.month == month)
        days = dates[mask].dt.day
        counts = days.value_counts().to_dict()
        return {str(int(k)): int(v) for k, v in counts.items()}
    except Exception as e:
        print(f"Could not compute campaign counts: {e}")
        return {}


def get_campaign_counts_by_year(year: int):
    """Returns {month: {day: count}} for the whole year, in one call."""
    df = load_latest_csv("campaigns")
    if df is None:
        return {}
    date_col = _find_date_column(df)
    if date_col is None:
        return {}
    try:
        dates = pd.to_datetime(df[date_col], errors="coerce")
        mask = dates.dt.year == year
        sub = dates[mask]
        result = {}
        for month in range(1, 13):
            month_days = sub[sub.dt.month == month].dt.day
            if len(month_days) > 0:
                counts = month_days.value_counts().to_dict()
                result[str(month)] = {str(int(k)): int(v) for k, v in counts.items()}
        return result
    except Exception as e:
        print(f"Could not compute yearly campaign counts: {e}")
        return {}


def get_calendar_notes(year: int, month: int):
    """Returns all notes for the given year/month as a list of {id, date, text}."""
    db = get_db()
    if not db:
        return []
    try:
        prefix = f"{year}-{month:02d}-"
        docs = db.collection(NOTES_COLLECTION).stream()
        results = []
        for doc in docs:
            data = doc.to_dict()
            if data.get("date", "").startswith(prefix):
                results.append({"id": doc.id, "date": data["date"], "text": data["text"], "category": data.get("category", "General")})
        return results
    except Exception as e:
        print(f"Could not load calendar notes: {e}")
        return []


def get_calendar_notes_year(year: int):
    """Returns all notes for the given year, no month filter."""
    db = get_db()
    if not db:
        return []
    try:
        prefix = f"{year}-"
        docs = db.collection(NOTES_COLLECTION).stream()
        results = []
        for doc in docs:
            data = doc.to_dict()
            if data.get("date", "").startswith(prefix):
                results.append({"id": doc.id, "date": data["date"], "text": data["text"], "category": data.get("category", "General")})
        return results
    except Exception as e:
        print(f"Could not load yearly calendar notes: {e}")
        return []


def add_calendar_note(date: str, text: str, category: str = "General"):
    db = get_db()
    if not db:
        return None
    try:
        doc_ref = db.collection(NOTES_COLLECTION).document()
        doc_ref.set({
            "date": date,
            "text": text,
            "category": category,
            "created_at": datetime.utcnow().isoformat(),
        })
        return doc_ref.id
    except Exception as e:
        print(f"Could not add calendar note: {e}")
        return None


def delete_calendar_note(note_id: str):
    db = get_db()
    if not db:
        return False
    try:
        db.collection(NOTES_COLLECTION).document(note_id).delete()
        return True
    except Exception as e:
        print(f"Could not delete calendar note: {e}")
        return False