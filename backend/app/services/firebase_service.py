from app.firebase_config import db

def get_db():
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

