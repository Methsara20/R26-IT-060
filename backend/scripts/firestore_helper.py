import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

FIREBASE_KEY_PATH = BASE_DIR / "app" / "config" / "firebase_key.json"
DATA_DIR = BASE_DIR / "scripts"/ "data"


def initialize_firestore():
    if not firebase_admin._apps:
        cred = credentials.Certificate(str(FIREBASE_KEY_PATH))
        firebase_admin.initialize_app(cred)

    return firestore.client()


db = initialize_firestore()


def clean_value(value):
    if pd.isna(value):
        return None

    if isinstance(value, pd.Timestamp):
        return value.isoformat()

    return value


def upload_csv_to_firestore(csv_file, collection_name, document_id_column):
    file_path = DATA_DIR / csv_file

    if not file_path.exists():
        raise FileNotFoundError(f"CSV file not found: {file_path}")

    df = pd.read_csv(file_path)

    print(f"Uploading {csv_file} to collection: {collection_name}")
    print(f"Rows: {len(df)}")

    batch = db.batch()
    batch_count = 0
    total_uploaded = 0

    for _, row in df.iterrows():
        row_dict = {
            col: clean_value(row[col])
            for col in df.columns
        }

        document_id = str(row_dict[document_id_column])

        doc_ref = db.collection(collection_name).document(document_id)
        batch.set(doc_ref, row_dict)

        batch_count += 1
        total_uploaded += 1

        if batch_count == 450:
            batch.commit()
            batch = db.batch()
            batch_count = 0
            print(f"Uploaded {total_uploaded} records...")

    if batch_count > 0:
        batch.commit()

    print(f"Completed upload: {collection_name}")
    print("-" * 50)