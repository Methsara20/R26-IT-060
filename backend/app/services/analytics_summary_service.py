from datetime import datetime

from app.services.firebase_service import (
    get_document_by_id,
    get_collection,
    create_or_update_document
)

from app.constants.collections import (
    PRODUCTS_COLLECTION,
    INVENTORY_COLLECTION,
    ANALYTICS_SUMMARY_COLLECTION,
    SHOWROOM_ANALYTICS_COLLECTION,
    CATEGORY_ANALYTICS_COLLECTION,
    BRAND_ANALYTICS_COLLECTION,
    GENDER_ANALYTICS_COLLECTION
)


OVERSTOCK_THRESHOLD = 0.85


def to_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def to_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def is_low_stock(current_stock, reorder_level):
    return current_stock <= reorder_level


def is_overstock(current_stock, max_stock):
    return max_stock > 0 and current_stock >= (max_stock * OVERSTOCK_THRESHOLD)


def calculate_inventory_contribution(inventory_item, product):
    current_stock = to_int(inventory_item.get("current_stock"))
    reorder_level = to_int(inventory_item.get("reorder_level"))
    max_stock = to_int(inventory_item.get("max_stock"))

    cost_price = to_float(product.get("cost_price"))
    selling_price = to_float(product.get("selling_price"))

    return {
        "stock": current_stock,
        "inventory_value": current_stock * cost_price,
        "potential_revenue": current_stock * selling_price,
        "potential_profit": current_stock * (selling_price - cost_price),
        "low_stock": is_low_stock(current_stock, reorder_level),
        "overstock": is_overstock(current_stock, max_stock)
    }


def update_summary_document(collection_name, document_id, old_contribution, new_contribution):
    summary = get_document_by_id(collection_name, document_id)

    if summary is None:
        return

    summary["total_stock"] = (
        to_int(summary.get("total_stock"))
        - old_contribution["stock"]
        + new_contribution["stock"]
    )

    summary["inventory_value"] = round(
        to_float(summary.get("inventory_value"))
        - old_contribution["inventory_value"]
        + new_contribution["inventory_value"],
        2
    )

    summary["potential_revenue"] = round(
        to_float(summary.get("potential_revenue"))
        - old_contribution["potential_revenue"]
        + new_contribution["potential_revenue"],
        2
    )

    summary["potential_profit"] = round(
        to_float(summary.get("potential_profit"))
        - old_contribution["potential_profit"]
        + new_contribution["potential_profit"],
        2
    )

    summary["low_stock_items"] = (
        to_int(summary.get("low_stock_items"))
        - (1 if old_contribution["low_stock"] else 0)
        + (1 if new_contribution["low_stock"] else 0)
    )

    summary["overstock_items"] = (
        to_int(summary.get("overstock_items"))
        - (1 if old_contribution["overstock"] else 0)
        + (1 if new_contribution["overstock"] else 0)
    )

    summary["last_updated"] = datetime.now().isoformat()

    create_or_update_document(
        collection_name,
        document_id,
        summary
    )


def update_dashboard_summary(old_contribution, new_contribution):
    dashboard = get_document_by_id(
        ANALYTICS_SUMMARY_COLLECTION,
        "dashboard"
    )

    if dashboard is None:
        return

    dashboard["total_inventory_quantity"] = (
        to_int(dashboard.get("total_inventory_quantity"))
        - old_contribution["stock"]
        + new_contribution["stock"]
    )

    dashboard["total_inventory_value"] = round(
        to_float(dashboard.get("total_inventory_value"))
        - old_contribution["inventory_value"]
        + new_contribution["inventory_value"],
        2
    )

    dashboard["total_potential_revenue"] = round(
        to_float(dashboard.get("total_potential_revenue"))
        - old_contribution["potential_revenue"]
        + new_contribution["potential_revenue"],
        2
    )

    dashboard["total_potential_profit"] = round(
        to_float(dashboard.get("total_potential_profit"))
        - old_contribution["potential_profit"]
        + new_contribution["potential_profit"],
        2
    )

    dashboard["low_stock_items"] = (
        to_int(dashboard.get("low_stock_items"))
        - (1 if old_contribution["low_stock"] else 0)
        + (1 if new_contribution["low_stock"] else 0)
    )

    dashboard["overstock_items"] = (
        to_int(dashboard.get("overstock_items"))
        - (1 if old_contribution["overstock"] else 0)
        + (1 if new_contribution["overstock"] else 0)
    )

    dashboard["last_updated"] = datetime.now().isoformat()

    create_or_update_document(
        ANALYTICS_SUMMARY_COLLECTION,
        "dashboard",
        dashboard
    )


def refresh_summaries_after_inventory_update(old_inventory, new_inventory):
    product_id = new_inventory.get("product_id")

    product = get_document_by_id(
        PRODUCTS_COLLECTION,
        product_id
    )

    if product is None:
        return

    old_contribution = calculate_inventory_contribution(
        old_inventory,
        product
    )

    new_contribution = calculate_inventory_contribution(
        new_inventory,
        product
    )

    store_id = new_inventory.get("store_id")
    category = product.get("category", "Unknown")
    brand = product.get("brand", "Unknown")
    gender = product.get("gender", "Unknown")

    update_dashboard_summary(
        old_contribution,
        new_contribution
    )

    update_summary_document(
        SHOWROOM_ANALYTICS_COLLECTION,
        store_id,
        old_contribution,
        new_contribution
    )

    update_summary_document(
        CATEGORY_ANALYTICS_COLLECTION,
        category,
        old_contribution,
        new_contribution
    )

    update_summary_document(
        BRAND_ANALYTICS_COLLECTION,
        brand,
        old_contribution,
        new_contribution
    )

    update_summary_document(
        GENDER_ANALYTICS_COLLECTION,
        gender,
        old_contribution,
        new_contribution
    )