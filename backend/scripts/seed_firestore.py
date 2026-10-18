from scripts.upload_products import upload_products
from scripts.upload_stores import upload_stores
from scripts.upload_inventory_current import upload_inventory_current


def seed_firestore():
    upload_products()
    upload_stores()
    upload_inventory_current()

    print("All CSV files uploaded to Firestore successfully.")


if __name__ == "__main__":
    seed_firestore()