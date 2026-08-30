"""
backend/inventory_service.py
Read-only access to the inventory component's Firestore collections
(built by a teammate on the shared team Firebase project — finalyear-6bafb).

IMPORTANT: this module only ever READS from these collections — it never
writes, updates, or deletes anything, so there is no risk to the teammate's
data no matter what we call here.

Uses the SEPARATE shared Firebase connection (get_shared_db) defined in
firebase_config.py — this is intentionally kept apart from this project's
own private Firebase project (used for campaigns, customers, calendar
notes, etc.) to avoid any shared-quota impact from this component's own
testing.
"""
from app.config.firebase_config import get_shared_db


def preview_collection(collection_name: str, limit: int = 5):
    """
    Read-only preview: returns up to `limit` documents from a given collection,
    each as {id, fields}. Used to inspect real data structure safely.
    """
    db = get_shared_db()
    if not db:
        return {"error": "Shared Firebase not connected"}
    try:
        docs = db.collection(collection_name).limit(limit).stream()
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
    db = get_shared_db()
    if not db:
        return {"error": "Shared Firebase not connected"}
    try:
        doc = db.collection("alert_items").document("overstock").get()
        if not doc.exists:
            return {"error": "No overstock data found"}
        data = doc.to_dict()
        items = data.get("items", [])
        if category:
            items = [i for i in items if i.get("category", "").lower() == category.lower()]
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


def get_marketing_opportunities(
    category: str = None,
    gender: str = None,
    store_id: str = None,
    year: int = None,
    month: int = None,
    limit: int = 20,
):
    """
    Reads the inventory component's 'marketing_opportunities' collection —
    products the Inventory team has flagged with recommended_action =
    'PROMOTE' (overstocked items worth featuring in a promotion).
    Supports filtering by category, gender, store, and/or created_at
    year/month. Read-only.
    """
    db = get_shared_db()
    if not db:
        return {"error": "Shared Firebase not connected"}
    try:
        docs = db.collection("marketing_opportunities").stream()
        opportunities = []
        for doc in docs:
            data = doc.to_dict()

            if category and data.get("category", "").lower() != category.lower():
                continue
            if gender and data.get("gender", "").lower() != gender.lower():
                continue
            if store_id and data.get("store_id", "").lower() != store_id.lower():
                continue

            created_at = data.get("created_at") or ""
            if year is not None or month is not None:
                try:
                    parsed_date = created_at[:10]  # "YYYY-MM-DD" prefix of the ISO string
                    doc_year = int(parsed_date[0:4])
                    doc_month = int(parsed_date[5:7])
                except (ValueError, IndexError):
                    continue
                if year is not None and doc_year != year:
                    continue
                if month is not None and doc_month != month:
                    continue

            opportunities.append({
                "opportunity_id": data.get("opportunity_id"),
                "product_id": data.get("product_id"),
                "product_name": data.get("product_name"),
                "store_id": data.get("store_id"),
                "category": data.get("category"),
                "subcategory": data.get("subcategory"),
                "brand": data.get("brand"),
                "gender": data.get("gender"),
                "current_stock": data.get("current_stock"),
                "excess_quantity": data.get("excess_quantity"),
                "selling_price": data.get("selling_price"),
                "recommended_action": data.get("recommended_action"),
                "status": data.get("status"),
                "created_at": created_at,
            })

        opportunities.sort(key=lambda o: o.get("created_at") or "", reverse=True)

        return {
            "count": len(opportunities),
            "opportunities": opportunities[:limit],
        }
    except Exception as e:
        return {"error": str(e)}


def get_marketing_opportunities_summary():
    """
    Returns aggregate stats across ALL marketing_opportunities (no filters
    applied here — filtering happens client-side/via get_marketing_opportunities
    for the record list, this endpoint powers the summary cards, charts, and
    gives the available filter options so the UI only offers real, existing
    values).
    """
    db = get_shared_db()
    if not db:
        return {"error": "Shared Firebase not connected"}
    try:
        docs = db.collection("marketing_opportunities").stream()

        total_items = 0
        total_excess_units = 0
        total_value_at_risk = 0.0
        categories = set()
        genders = set()
        store_ids = set()
        months_available = set()  # "YYYY-MM" strings

        excess_units_by_category = {}  # for the bar chart
        item_count_by_category = {}    # for the donut chart

        for doc in docs:
            data = doc.to_dict()
            total_items += 1

            excess = data.get("excess_quantity") or 0
            price = data.get("selling_price") or 0
            total_excess_units += excess
            total_value_at_risk += excess * price

            category = data.get("category")
            if category:
                categories.add(category)
                excess_units_by_category[category] = excess_units_by_category.get(category, 0) + excess
                item_count_by_category[category] = item_count_by_category.get(category, 0) + 1

            if data.get("gender"):
                genders.add(data["gender"])
            if data.get("store_id"):
                store_ids.add(data["store_id"])

            created_at = data.get("created_at") or ""
            if len(created_at) >= 7:
                months_available.add(created_at[:7])  # "YYYY-MM"

        return {
            "total_items": total_items,
            "total_excess_units": total_excess_units,
            "total_value_at_risk": round(total_value_at_risk, 2),
            "available_categories": sorted(categories),
            "available_genders": sorted(genders),
            "available_store_ids": sorted(store_ids),
            "available_months": sorted(months_available, reverse=True),
            "excess_units_by_category": excess_units_by_category,
            "item_count_by_category": item_count_by_category,
        }
    except Exception as e:
        return {"error": str(e)}


def list_collections():
    """Read-only: lists top-level collection names in the shared database."""
    db = get_shared_db()
    if not db:
        return {"error": "Shared Firebase not connected"}
    try:
        collections = db.collections()
        return {"collections": [c.id for c in collections]}
    except Exception as e:
        return {"error": str(e)}