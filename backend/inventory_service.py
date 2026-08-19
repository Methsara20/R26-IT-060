"""
backend/inventory_service.py
Read-only access to the inventory component's Firestore collections
(built by a teammate on the same shared Firebase project).

IMPORTANT: this module only ever READS from these collections — it never
writes, updates, or deletes anything, so there is no risk to the teammate's
data no matter what we call here.

We start with a generic preview function so we can see the real document
structure before building any overstock-suggestion logic on top of it —
safer than guessing field names.
"""

import os

FIREBASE_KEY_PATH = "firebase-key.json"

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


def preview_collection(collection_name: str, limit: int = 5):
    """
    Read-only preview: returns up to `limit` documents from a given collection,
    each as {id, fields}. Used to inspect real data structure safely.
    """
    if not init_firebase():
        return {"error": "Firebase not connected"}

    try:
        docs = _db.collection(collection_name).limit(limit).stream()
        results = []
        for doc in docs:
            results.append({"id": doc.id, "fields": doc.to_dict()})
        return {"collection": collection_name, "document_count": len(results), "documents": results}
    except Exception as e:
        return {"error": str(e)}


def get_overstock_suggestions(category: str = None, limit: int = 10):
    """
    Reads the inventory component's precomputed 'overstock' alert
    (alert_items/overstock), which already lists overstocked products with
    stock levels, store, brand, and category. Optionally filters by category
    to match a marketing campaign's target category (e.g. 'Women', 'Footwear').

    Read-only — never modifies the teammate's data.
    """
    if not init_firebase():
        return {"error": "Firebase not connected"}

    try:
        doc = _db.collection("alert_items").document("overstock").get()
        if not doc.exists:
            return {"error": "No overstock data found"}

        data = doc.to_dict()
        items = data.get("items", [])

        if category:
            items = [i for i in items if i.get("category", "").lower() == category.lower()]

        # Sort by how far over reorder level they are (most overstocked first)
        items = sorted(items, key=lambda i: i.get("current_stock", 0) - i.get("reorder_level", 0), reverse=True)

        suggestions = [{
            "product_name": i.get("product_name"),
            "brand": i.get("brand"),
            "category": i.get("category"),
            "store_id": i.get("store_id"),
            "current_stock": i.get("current_stock"),
            "reorder_level": i.get("reorder_level"),
            "excess_units": i.get("current_stock", 0) - i.get("reorder_level", 0),
        } for i in items[:limit]]

        return {
            "count": len(suggestions),
            "last_updated": data.get("last_updated"),
            "suggestions": suggestions,
        }
    except Exception as e:
        return {"error": str(e)}


def list_collections():
    """Read-only: lists top-level collection names in the database."""
    if not init_firebase():
        return {"error": "Firebase not connected"}
    try:
        collections = _db.collections()
        return {"collections": [c.id for c in collections]}
    except Exception as e:
        return {"error": str(e)}