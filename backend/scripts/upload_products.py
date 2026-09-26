from scripts.firestore_helper import upload_csv_to_firestore


def upload_products():
    upload_csv_to_firestore(
        csv_file="products_updated.csv",
        collection_name="products",
        document_id_column="product_id"
    )


if __name__ == "__main__":
    upload_products()