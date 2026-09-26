import pandas as pd

INVENTORY_PATH = "app/data/inventory_2026.csv"


def load_inventory():
    return pd.read_csv(INVENTORY_PATH)


def get_product_stock(inventory, store_id, product_id):
    row = inventory[
        (inventory["store_id"] == store_id) &
        (inventory["product_id"] == product_id)
    ]

    if row.empty:
        return None

    return row.iloc[0].to_dict()


def find_transfer_source(inventory, target_store, product_id):
    candidates = inventory[
        (inventory["store_id"] != target_store) &
        (inventory["product_id"] == product_id)
    ].copy()

    candidates["surplus"] = candidates["current_stock"] - candidates["reorder_level"]
    candidates = candidates[candidates["surplus"] > 0]

    if candidates.empty:
        return None

    best = candidates.sort_values("surplus", ascending=False).iloc[0]
    return best.to_dict()


def make_decision(store_id, product_id, predicted_demand):
    inventory = load_inventory()

    current = get_product_stock(inventory, store_id, product_id)

    if current is None:
        return {"error": "Product not found in inventory"}

    stock = current["current_stock"]
    reorder = current["reorder_level"]
    max_stock = current["max_stock"]

    # SAFE
    if stock >= predicted_demand:
        return {
            "current_stock": stock,
            "status": "SAFE",
            "action": "NO_ACTION",
            "from_store": None,
            "transfer_qty": 0
        }

    # LOW STOCK
    shortage = int(predicted_demand - stock)

    source = find_transfer_source(inventory, store_id, product_id)

    if source:
        transfer_qty = min(shortage, source["current_stock"] - source["reorder_level"])

        return {
            "current_stock": stock,
            "status": "LOW_STOCK",
            "action": "TRANSFER",
            "from_store": source["store_id"],
            "transfer_qty": int(transfer_qty)
        }

    return {
        "current_stock": stock,
        "status": "LOW_STOCK",
        "action": "REORDER",
        "from_store": None,
        "transfer_qty": shortage
    }