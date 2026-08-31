from firestore_helper import upload_csv_to_firestore


def upload_store_distances():
    upload_csv_to_firestore(
        csv_file="store_distances.csv",
        collection_name="store_distances",
        document_id_column="distance_id"
    )


if __name__ == "__main__":
    upload_store_distances()

