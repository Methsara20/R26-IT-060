from scripts.firestore_helper import upload_csv_to_firestore


def upload_inventory_current():
    upload_csv_to_firestore(
        csv_file="inventory_current.csv",
        collection_name="inventory_current",
        document_id_column="inventory_id"
    )


if __name__ == "__main__":
    upload_inventory_current()