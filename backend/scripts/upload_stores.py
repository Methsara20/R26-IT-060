from scripts.firestore_helper import upload_csv_to_firestore


def upload_stores():
    upload_csv_to_firestore(
        csv_file="stores.csv",
        collection_name="stores",
        document_id_column="store_id"
    )


if __name__ == "__main__":
    upload_stores()