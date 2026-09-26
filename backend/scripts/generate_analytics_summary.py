from datetime import datetime

from app.services.firebase_service import (
    get_all_documents,
    create_or_update_document
)

from app.constants.collections import (
    PRODUCTS_COLLECTION,
    STORES_COLLECTION,
    INVENTORY_COLLECTION,
    ANALYTICS_SUMMARY_COLLECTION,
    SHOWROOM_ANALYTICS_COLLECTION,
    CATEGORY_ANALYTICS_COLLECTION,
    BRAND_ANALYTICS_COLLECTION,
    GENDER_ANALYTICS_COLLECTION,
    ALERT_ITEMS_COLLECTION
)


OVERSTOCK_THRESHOLD = 0.85


def to_int(value):
    try:
        return int(value)
    except:
        return 0


def to_float(value):
    try:
        return float(value)
    except:
        return 0.0


def is_low_stock(current_stock, reorder_level):
    return current_stock <= reorder_level


def is_overstock(current_stock, max_stock):
    return max_stock > 0 and current_stock >= (max_stock * OVERSTOCK_THRESHOLD)


def round_money(item):
    for key in ["inventory_value", "potential_revenue", "potential_profit"]:
        item[key] = round(item.get(key, 0), 2)
    return item


def add_to_group(summary, key, field_name, stock, cost_price, selling_price, low_stock, overstock):
    if key not in summary:
        summary[key] = {
            field_name: key,
            "total_stock": 0,
            "inventory_value": 0,
            "potential_revenue": 0,
            "potential_profit": 0,
            "low_stock_items": 0,
            "overstock_items": 0
        }

    summary[key]["total_stock"] += stock
    summary[key]["inventory_value"] += stock * cost_price
    summary[key]["potential_revenue"] += stock * selling_price
    summary[key]["potential_profit"] += stock * (selling_price - cost_price)

    if low_stock:
        summary[key]["low_stock_items"] += 1

    if overstock:
        summary[key]["overstock_items"] += 1


def generate_analytics_summary():
    print("Loading products...")
    products = get_all_documents(PRODUCTS_COLLECTION)

    print("Loading stores...")
    stores = get_all_documents(STORES_COLLECTION)

    print("Loading inventory...")
    inventory = get_all_documents(INVENTORY_COLLECTION)

    product_lookup = {
        p["product_id"]: p
        for p in products
    }

    store_lookup = {
        s["store_id"]: s
        for s in stores
    }

    dashboard = {
        "total_products": len(products),
        "total_stores": len(stores),
        "total_inventory_records": len(inventory),
        "total_inventory_quantity": 0,
        "total_inventory_value": 0,
        "total_potential_revenue": 0,
        "total_potential_profit": 0,
        "low_stock_items": 0,
        "overstock_items": 0,
        "last_updated": datetime.now().isoformat()
    }

    showroom_summary = {}
    category_summary = {}
    brand_summary = {}
    gender_summary = {}

    low_stock_items = []
    overstock_items = []
    high_value_inventory = []

    for item in inventory:
        product_id = item.get("product_id")
        store_id = item.get("store_id")

        product = product_lookup.get(product_id, {})
        store = store_lookup.get(store_id, {})

        current_stock = to_int(item.get("current_stock"))
        reorder_level = to_int(item.get("reorder_level"))
        max_stock = to_int(item.get("max_stock"))

        cost_price = to_float(product.get("cost_price"))
        selling_price = to_float(product.get("selling_price"))

        inventory_value = current_stock * cost_price
        potential_revenue = current_stock * selling_price
        potential_profit = current_stock * (selling_price - cost_price)

        low_stock = is_low_stock(current_stock, reorder_level)
        overstock = is_overstock(current_stock, max_stock)

        dashboard["total_inventory_quantity"] += current_stock
        dashboard["total_inventory_value"] += inventory_value
        dashboard["total_potential_revenue"] += potential_revenue
        dashboard["total_potential_profit"] += potential_profit

        if low_stock:
            dashboard["low_stock_items"] += 1
            low_stock_items.append({
                **item,
                "product_name": product.get("product_name", ""),
                "category": product.get("category", ""),
                "brand": product.get("brand", ""),
                "current_stock": current_stock,
                "reorder_level": reorder_level
            })

        if overstock:
            dashboard["overstock_items"] += 1
            overstock_items.append({
                **item,
                "product_name": product.get("product_name", ""),
                "category": product.get("category", ""),
                "brand": product.get("brand", ""),
                "current_stock": current_stock,
                "max_stock": max_stock
            })

        high_value_inventory.append({
            **item,
            "product_name": product.get("product_name", ""),
            "category": product.get("category", ""),
            "brand": product.get("brand", ""),
            "gender": product.get("gender", ""),
            "inventory_value": round(inventory_value, 2)
        })

        if store_id not in showroom_summary:
            showroom_summary[store_id] = {
                "store_id": store_id,
                "store_name": store.get("store_name", ""),
                "city": store.get("city", ""),
                "total_stock": 0,
                "inventory_value": 0,
                "potential_revenue": 0,
                "potential_profit": 0,
                "low_stock_items": 0,
                "overstock_items": 0
            }

        showroom_summary[store_id]["total_stock"] += current_stock
        showroom_summary[store_id]["inventory_value"] += inventory_value
        showroom_summary[store_id]["potential_revenue"] += potential_revenue
        showroom_summary[store_id]["potential_profit"] += potential_profit

        if low_stock:
            showroom_summary[store_id]["low_stock_items"] += 1

        if overstock:
            showroom_summary[store_id]["overstock_items"] += 1

        add_to_group(
            category_summary,
            product.get("category", "Unknown"),
            "category",
            current_stock,
            cost_price,
            selling_price,
            low_stock,
            overstock
        )

        add_to_group(
            brand_summary,
            product.get("brand", "Unknown"),
            "brand",
            current_stock,
            cost_price,
            selling_price,
            low_stock,
            overstock
        )

        add_to_group(
            gender_summary,
            product.get("gender", "Unknown"),
            "gender",
            current_stock,
            cost_price,
            selling_price,
            low_stock,
            overstock
        )

    # dashboard = round_money(dashboard)

    dashboard["total_inventory_value"] = round(
        dashboard["total_inventory_value"],
        2
    )

    dashboard["total_potential_revenue"] = round(
        dashboard["total_potential_revenue"],
        2
    )

    dashboard["total_potential_profit"] = round(
        dashboard["total_potential_profit"],
        2
    )



    print("Saving dashboard summary...")
    create_or_update_document(
        ANALYTICS_SUMMARY_COLLECTION,
        "dashboard",
        dashboard,
        merge=False
    )

    print("Saving showroom analytics...")
    for store_id, data in showroom_summary.items():
        create_or_update_document(
            SHOWROOM_ANALYTICS_COLLECTION,
            store_id,
            round_money(data)
        )

    print("Saving category analytics...")
    for category, data in category_summary.items():
        create_or_update_document(
            CATEGORY_ANALYTICS_COLLECTION,
            category,
            round_money(data)
        )

    print("Saving brand analytics...")
    for brand, data in brand_summary.items():
        create_or_update_document(
            BRAND_ANALYTICS_COLLECTION,
            brand,
            round_money(data)
        )

    print("Saving gender analytics...")
    for gender, data in gender_summary.items():
        create_or_update_document(
            GENDER_ANALYTICS_COLLECTION,
            gender,
            round_money(data)
        )

    low_stock_items = sorted(
        low_stock_items,
        key=lambda x: to_int(x.get("current_stock"))
    )[:50]

    overstock_items = sorted(
        overstock_items,
        key=lambda x: to_int(x.get("current_stock")),
        reverse=True
    )[:50]

    high_value_inventory = sorted(
        high_value_inventory,
        key=lambda x: x.get("inventory_value", 0),
        reverse=True
    )[:50]

    print("Saving alert items...")
    create_or_update_document(
        ALERT_ITEMS_COLLECTION,
        "low_stock",
        {
            "count": len(low_stock_items),
            "items": low_stock_items,
            "last_updated": datetime.now().isoformat()
        }
    )

    create_or_update_document(
        ALERT_ITEMS_COLLECTION,
        "overstock",
        {
            "count": len(overstock_items),
            "items": overstock_items,
            "last_updated": datetime.now().isoformat()
        }
    )

    create_or_update_document(
        ALERT_ITEMS_COLLECTION,
        "high_value_inventory",
        {
            "count": len(high_value_inventory),
            "items": high_value_inventory,
            "last_updated": datetime.now().isoformat()
        }
    )

    print("Analytics summary generated successfully.")


if __name__ == "__main__":
    generate_analytics_summary()