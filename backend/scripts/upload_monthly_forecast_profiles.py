import argparse
import math
from pathlib import Path

import pandas as pd

import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore


COLLECTION_NAME = "monthly_forecast_profiles"

DEFAULT_BATCH_SIZE = 400


# ==========================================================
# HELPERS
# ==========================================================

def clean_document_part(value) -> str:
    """
    Convert a value into a Firestore-safe document-id part.
    """

    text = str(value).strip()

    return (
        text
        .replace("/", "-")
        .replace("\\", "-")
        .replace(" ", "_")
    )


def build_document_id(row: dict) -> str:
    """
    Example:

    CP005_Kids_Hustle_Kids_M09
    """

    store_id = clean_document_part(
        row["store_id"]
    )

    category = clean_document_part(
        row["category"]
    )

    brand = clean_document_part(
        row["brand"]
    )

    gender = clean_document_part(
        row["gender"]
    )

    month = int(row["month"])

    return (
        f"{store_id}_"
        f"{category}_"
        f"{brand}_"
        f"{gender}_"
        f"M{month:02d}"
    )


def clean_value(value):
    """
    Convert pandas/numpy values into Firestore-safe
    Python values.
    """

    if pd.isna(value):
        return None

    if hasattr(value, "item"):
        value = value.item()

    if isinstance(value, float):

        if math.isnan(value):
            return None

        return float(value)

    if isinstance(value, int):
        return int(value)

    return value


def row_to_document(row) -> dict:

    document = {}

    for column, value in row.items():

        document[column] = (
            clean_value(value)
        )

    # Ensure important integer fields
    # remain integers.

    integer_fields = [
        "month",
        "historical_year_count",
        "unique_products_sold",
        "holiday_days",
        "festival_days",
        "school_days",
        "weekend_days",
        "promotion_days",
    ]

    for field in integer_fields:

        if document.get(field) is not None:

            document[field] = int(
                document[field]
            )

    document[
        "profile_version"
    ] = 1

    document[
        "profile_type"
    ] = "HISTORICAL_SEASONAL_PROFILE"

    return document


# ==========================================================
# FIREBASE
# ==========================================================

def initialize_firestore(
    credentials_path: Path
):

    if not credentials_path.exists():

        raise FileNotFoundError(
            f"Firebase credentials file "
            f"not found: "
            f"{credentials_path}"
        )

    if not firebase_admin._apps:

        cred = credentials.Certificate(
            str(credentials_path)
        )

        firebase_admin.initialize_app(
            cred
        )

    return firestore.client()


# ==========================================================
# UPLOAD
# ==========================================================

def upload_profiles(
    db,
    dataframe: pd.DataFrame,
    batch_size: int
):

    collection = db.collection(
        COLLECTION_NAME
    )

    total_rows = len(dataframe)

    uploaded = 0

    print()
    print(
        f"Preparing to upload "
        f"{total_rows} profiles..."
    )

    for start_index in range(
        0,
        total_rows,
        batch_size
    ):

        batch = db.batch()

        end_index = min(
            start_index + batch_size,
            total_rows
        )

        batch_df = dataframe.iloc[
            start_index:end_index
        ]

        for _, row in batch_df.iterrows():

            row_dict = row.to_dict()

            document_id = (
                build_document_id(
                    row_dict
                )
            )

            document_data = (
                row_to_document(
                    row_dict
                )
            )

            document_ref = (
                collection.document(
                    document_id
                )
            )

            # set() makes this script safe to rerun.
            # Same deterministic ID is replaced,
            # not duplicated.

            batch.set(
                document_ref,
                document_data
            )

        batch.commit()

        uploaded += len(batch_df)

        print(
            f"Uploaded "
            f"{uploaded}/{total_rows}"
        )

    print()
    print("=" * 60)
    print("UPLOAD COMPLETE")
    print("=" * 60)

    print(
        "Collection:",
        COLLECTION_NAME
    )

    print(
        "Documents processed:",
        uploaded
    )


# ==========================================================
# MAIN
# ==========================================================

def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--csv",
        required=True,
        help=(
            "Path to "
            "monthly_forecast_profiles.csv"
        )
    )

    parser.add_argument(
        "--credentials",
        required=True,
        help=(
            "Path to Firebase "
            "service account JSON file"
        )
    )

    parser.add_argument(
        "--batch-size",
        type=int,
        default=DEFAULT_BATCH_SIZE
    )

    args = parser.parse_args()

    csv_path = Path(
        args.csv
    )

    credentials_path = Path(
        args.credentials
    )

    if not csv_path.exists():

        raise FileNotFoundError(
            f"CSV not found: {csv_path}"
        )

    print(
        "Loading monthly forecast profiles..."
    )

    dataframe = pd.read_csv(
        csv_path
    )

    print(
        "Profiles found:",
        len(dataframe)
    )

    required_columns = {
        "store_id",
        "category",
        "brand",
        "gender",
        "month",
    }

    missing_columns = (
        required_columns
        - set(dataframe.columns)
    )

    if missing_columns:

        raise ValueError(
            "Missing required columns: "
            f"{sorted(missing_columns)}"
        )

    duplicate_count = (
        dataframe.duplicated(
            subset=[
                "store_id",
                "category",
                "brand",
                "gender",
                "month",
            ]
        )
        .sum()
    )

    if duplicate_count:

        raise ValueError(
            f"Found {duplicate_count} "
            "duplicate profile keys."
        )

    db = initialize_firestore(
        credentials_path
    )

    upload_profiles(
        db=db,
        dataframe=dataframe,
        batch_size=args.batch_size
    )


if __name__ == "__main__":
    main()