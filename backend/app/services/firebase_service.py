from app.firebase_config import db

def get_db():
    return db


def get_collection(collection_name: str):
    database = get_db()
    return database.collection(collection_name)


def get_all_documents(collection_name: str):
    docs = get_collection(collection_name).stream()

    data = []
    for doc in docs:
        item = doc.to_dict()
        item["id"] = doc.id
        data.append(item)

    return data


def get_document_by_id(collection_name: str, document_id: str):
    doc = get_collection(collection_name).document(document_id).get()

    if not doc.exists:
        return None

    item = doc.to_dict()
    item["id"] = doc.id
    return item


# def create_or_update_document(collection_name: str, document_id: str, data: dict):
#     get_collection(collection_name).document(document_id).set(data, merge=True)
#
#     return {
#         "message": "Document saved successfully",
#         "collection": collection_name,
#         "document_id": document_id
#     }

def create_or_update_document(
    collection_name: str,
    document_id: str,
    data: dict,
    merge: bool = True
):
    get_collection(collection_name).document(document_id).set(
        data,
        merge=merge
    )

    return {
        "message": "Document saved successfully",
        "collection": collection_name,
        "document_id": document_id
    }


def update_document(collection_name: str, document_id: str, data: dict):
    doc_ref = get_collection(collection_name).document(document_id)

    if not doc_ref.get().exists:
        return None

    doc_ref.update(data)

    return {
        "message": "Document updated successfully",
        "collection": collection_name,
        "document_id": document_id
    }


def delete_document(collection_name: str, document_id: str):
    doc_ref = get_collection(collection_name).document(document_id)

    if not doc_ref.get().exists:
        return None

    doc_ref.delete()

    return {
        "message": "Document deleted successfully",
        "collection": collection_name,
        "document_id": document_id
    }