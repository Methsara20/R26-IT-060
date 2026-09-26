from pathlib import Path
import argparse

import pandas as pd


# ==========================================================
# CONFIGURATION
# ==========================================================

BASE_DIR = Path(__file__).resolve().parent.parent

DEFAULT_OUTPUT_DIR = (
    BASE_DIR
    / "app"
    / "data"
    / "generated"
)


# ==========================================================
# REQUIRED COLUMNS
# ==========================================================

SALES_COLUMNS = {
    "date",
    "store_id",
    "product_id",
    "units_sold",
    "price_lkr",
    "promotion_percent",
    "revenue",
    "customer_count",
}

PRODUCT_COLUMNS = {
    "product_id",
    "category",
    "brand",
    "gender",
}

EVENT_COLUMNS = {
    "date",
    "is_holiday",
    "is_festival",
    "is_school",
    "is_weekend",
}

PROMOTION_COLUMNS = {
    "date",
    "product_id",
    "store_id",
    "promotion_percent",
}


# ==========================================================
# VALIDATION
# ==========================================================

def validate_columns(
    df: pd.DataFrame,
    required_columns: set,
    dataset_name: str,
):
    missing = (
        required_columns
        - set(df.columns)
    )

    if missing:
        raise ValueError(
            f"{dataset_name} is missing "
            f"required columns: "
            f"{sorted(missing)}"
        )


# ==========================================================
# LOAD DATA
# ==========================================================

def load_training_data(
    sales_path: Path,
    products_path: Path,
    events_path: Path,
    promotions_path: Path,
):
    print("Loading historical training data...")

    sales = pd.read_csv(
        sales_path
    )

    products = pd.read_csv(
        products_path
    )

    events = pd.read_csv(
        events_path
    )

    promotions = pd.read_csv(
        promotions_path
    )

    validate_columns(
        sales,
        SALES_COLUMNS,
        "Sales"
    )

    validate_columns(
        products,
        PRODUCT_COLUMNS,
        "Products"
    )

    validate_columns(
        events,
        EVENT_COLUMNS,
        "Events"
    )

    validate_columns(
        promotions,
        PROMOTION_COLUMNS,
        "Promotions"
    )

    return (
        sales,
        products,
        events,
        promotions,
    )


# ==========================================================
# DATE PREPARATION
# ==========================================================

def prepare_dates(
    sales: pd.DataFrame,
    events: pd.DataFrame,
    promotions: pd.DataFrame,
):
    sales = sales.copy()
    events = events.copy()
    promotions = promotions.copy()

    sales["date"] = pd.to_datetime(
        sales["date"]
    )

    events["date"] = pd.to_datetime(
        events["date"]
    )

    promotions["date"] = (
        pd.to_datetime(
            promotions["date"]
        )
    )

    sales["month_period"] = (
        sales["date"]
        .dt.to_period("M")
        .astype(str)
    )

    events["month_period"] = (
        events["date"]
        .dt.to_period("M")
        .astype(str)
    )

    promotions["month_period"] = (
        promotions["date"]
        .dt.to_period("M")
        .astype(str)
    )

    return (
        sales,
        events,
        promotions,
    )


# ==========================================================
# MONTHLY SALES
# ==========================================================

def build_monthly_sales(
    sales: pd.DataFrame,
    products: pd.DataFrame,
):
    """
    Reproduce the important sales aggregation
    used during monthly model training.
    """

    product_dimensions = (
        products[
            [
                "product_id",
                "category",
                "brand",
                "gender",
            ]
        ]
        .drop_duplicates(
            subset=["product_id"]
        )
    )

    sales_data = sales.merge(
        product_dimensions,
        on="product_id",
        how="left",
    )

    missing_product_info = (
        sales_data[
            [
                "category",
                "brand",
                "gender",
            ]
        ]
        .isna()
        .any(axis=1)
        .sum()
    )

    if missing_product_info:
        print(
            "Warning: "
            f"{missing_product_info} "
            "sales rows have missing "
            "product metadata."
        )

    group_columns = [
        "month_period",
        "store_id",
        "category",
        "brand",
        "gender",
    ]

    monthly_sales = (
        sales_data
        .groupby(
            group_columns,
            as_index=False,
        )
        .agg(
            monthly_units_sold=(
                "units_sold",
                "sum",
            ),

            avg_price_lkr=(
                "price_lkr",
                "mean",
            ),

            avg_promotion_percent=(
                "promotion_percent",
                "mean",
            ),

            total_revenue=(
                "revenue",
                "sum",
            ),

            total_customer_count=(
                "customer_count",
                "sum",
            ),

            unique_products_sold=(
                "product_id",
                "nunique",
            ),
        )
    )

    return monthly_sales


# ==========================================================
# MONTHLY EVENTS
# ==========================================================

def build_monthly_events(
    events: pd.DataFrame
):
    """
    Aggregate calendar/event features exactly
    at month level.
    """

    monthly_events = (
        events
        .groupby(
            "month_period",
            as_index=False,
        )
        .agg(
            holiday_days=(
                "is_holiday",
                "sum",
            ),

            festival_days=(
                "is_festival",
                "sum",
            ),

            school_days=(
                "is_school",
                "sum",
            ),

            weekend_days=(
                "is_weekend",
                "sum",
            ),
        )
    )

    return monthly_events


# ==========================================================
# MONTHLY PROMOTIONS
# ==========================================================

def build_monthly_promotions(
    promotions: pd.DataFrame,
    products: pd.DataFrame,
):
    product_dimensions = (
        products[
            [
                "product_id",
                "category",
                "brand",
                "gender",
            ]
        ]
        .drop_duplicates(
            subset=["product_id"]
        )
    )

    promotion_data = (
        promotions.merge(
            product_dimensions,
            on="product_id",
            how="left",
        )
    )

    group_columns = [
        "month_period",
        "store_id",
        "category",
        "brand",
        "gender",
    ]

    monthly_promotions = (
        promotion_data
        .groupby(
            group_columns,
            as_index=False,
        )
        .agg(
            promotion_days=(
                "promotion_percent",
                "count",
            ),

            max_promotion_percent=(
                "promotion_percent",
                "max",
            ),

            avg_campaign_discount=(
                "promotion_percent",
                "mean",
            ),
        )
    )

    return monthly_promotions


# ==========================================================
# LAG FEATURES
# ==========================================================

def add_historical_features(
    monthly_data: pd.DataFrame
):
    """
    Create demand-history features matching
    the semantics of the monthly model.

    These values describe historical demand;
    they are NOT live operational values.
    """

    data = monthly_data.copy()

    data["month_date"] = (
        pd.to_datetime(
            data["month_period"]
            + "-01"
        )
    )

    data["year"] = (
        data["month_date"].dt.year
    )

    data["month"] = (
        data["month_date"].dt.month
    )

    data["quarter"] = (
        data["month_date"].dt.quarter
    )

    group_columns = [
        "store_id",
        "category",
        "brand",
        "gender",
    ]

    data = data.sort_values(
        group_columns
        + ["month_date"]
    ).reset_index(drop=True)

    grouped = data.groupby(
        group_columns,
        group_keys=False,
    )

    # Previous month
    data[
        "previous_month_sales"
    ] = grouped[
        "monthly_units_sold"
    ].shift(1)

    # Previous 2-month mean
    data[
        "previous_2_month_avg"
    ] = grouped[
        "monthly_units_sold"
    ].transform(
        lambda series:
        series.shift(1)
        .rolling(
            window=2,
            min_periods=2,
        )
        .mean()
    )

    # Previous 3-month mean
    data[
        "previous_3_month_avg"
    ] = grouped[
        "monthly_units_sold"
    ].transform(
        lambda series:
        series.shift(1)
        .rolling(
            window=3,
            min_periods=3,
        )
        .mean()
    )

    # Previous 6-month mean
    data[
        "previous_6_month_avg"
    ] = grouped[
        "monthly_units_sold"
    ].transform(
        lambda series:
        series.shift(1)
        .rolling(
            window=6,
            min_periods=6,
        )
        .mean()
    )

    # Same calendar month last year
    data[
        "same_month_last_year"
    ] = grouped[
        "monthly_units_sold"
    ].shift(12)

    history_columns = [
        "previous_month_sales",
        "previous_2_month_avg",
        "previous_3_month_avg",
        "previous_6_month_avg",
        "same_month_last_year",
    ]

    data[
        history_columns
    ] = (
        data[
            history_columns
        ]
        .fillna(0)
    )

    # Same definitions used by
    # the monthly model training.
    data[
        "sales_growth_1m"
    ] = (
        data[
            "previous_month_sales"
        ]
        -
        data[
            "previous_2_month_avg"
        ]
    )

    data[
        "sales_growth_3m"
    ] = (
        data[
            "previous_3_month_avg"
        ]
        -
        data[
            "previous_6_month_avg"
        ]
    )

    return data


# ==========================================================
# BUILD DETAILED HISTORY
# ==========================================================

def build_monthly_history(
    sales: pd.DataFrame,
    products: pd.DataFrame,
    events: pd.DataFrame,
    promotions: pd.DataFrame,
):
    monthly_sales = (
        build_monthly_sales(
            sales,
            products,
        )
    )

    monthly_events = (
        build_monthly_events(
            events
        )
    )

    monthly_promotions = (
        build_monthly_promotions(
            promotions,
            products,
        )
    )

    monthly_data = (
        monthly_sales.merge(
            monthly_events,
            on="month_period",
            how="left",
        )
    )

    merge_columns = [
        "month_period",
        "store_id",
        "category",
        "brand",
        "gender",
    ]

    monthly_data = (
        monthly_data.merge(
            monthly_promotions,
            on=merge_columns,
            how="left",
        )
    )

    promotion_columns = [
        "promotion_days",
        "max_promotion_percent",
        "avg_campaign_discount",
    ]

    monthly_data[
        promotion_columns
    ] = (
        monthly_data[
            promotion_columns
        ]
        .fillna(0)
    )

    event_columns = [
        "holiday_days",
        "festival_days",
        "school_days",
        "weekend_days",
    ]

    monthly_data[
        event_columns
    ] = (
        monthly_data[
            event_columns
        ]
        .fillna(0)
    )

    monthly_data = (
        add_historical_features(
            monthly_data
        )
    )

    return monthly_data


# ==========================================================
# BUILD SEASONAL PROFILES
# ==========================================================

def build_seasonal_profiles(
    monthly_history: pd.DataFrame
):
    """
    Convert detailed 2021-2025 history into
    compact seasonal patterns.

    One row per:

    store
    category
    brand
    gender
    calendar month

    This is what the live system can use
    as a fallback historical pattern.

    Runtime will NOT read the source CSVs.
    """

    profile_group = [
        "store_id",
        "category",
        "brand",
        "gender",
        "month",
    ]

    profiles = (
        monthly_history
        .groupby(
            profile_group,
            as_index=False,
        )
        .agg(
            historical_year_count=(
                "year",
                "nunique",
            ),

            monthly_units_sold=(
                "monthly_units_sold",
                "mean",
            ),

            avg_price_lkr=(
                "avg_price_lkr",
                "mean",
            ),

            avg_promotion_percent=(
                "avg_promotion_percent",
                "mean",
            ),

            total_revenue=(
                "total_revenue",
                "mean",
            ),

            total_customer_count=(
                "total_customer_count",
                "mean",
            ),

            unique_products_sold=(
                "unique_products_sold",
                "mean",
            ),

            holiday_days=(
                "holiday_days",
                "mean",
            ),

            festival_days=(
                "festival_days",
                "mean",
            ),

            school_days=(
                "school_days",
                "mean",
            ),

            weekend_days=(
                "weekend_days",
                "mean",
            ),

            promotion_days=(
                "promotion_days",
                "mean",
            ),

            max_promotion_percent=(
                "max_promotion_percent",
                "mean",
            ),

            avg_campaign_discount=(
                "avg_campaign_discount",
                "mean",
            ),

            previous_month_sales=(
                "previous_month_sales",
                "mean",
            ),

            previous_2_month_avg=(
                "previous_2_month_avg",
                "mean",
            ),

            previous_3_month_avg=(
                "previous_3_month_avg",
                "mean",
            ),

            previous_6_month_avg=(
                "previous_6_month_avg",
                "mean",
            ),

            same_month_last_year=(
                "same_month_last_year",
                "mean",
            ),

            sales_growth_1m=(
                "sales_growth_1m",
                "mean",
            ),

            sales_growth_3m=(
                "sales_growth_3m",
                "mean",
            ),
        )
    )

    # ----------------------------------------------
    # COUNT-LIKE FIELDS
    # ----------------------------------------------

    integer_like_columns = [
        "historical_year_count",
        "unique_products_sold",
        "holiday_days",
        "festival_days",
        "school_days",
        "weekend_days",
        "promotion_days",
    ]

    for column in integer_like_columns:

        profiles[column] = (
            profiles[column]
            .round()
            .astype(int)
        )

    # ----------------------------------------------
    # NUMERIC PRECISION
    # ----------------------------------------------

    float_columns = [
        column
        for column
        in profiles.columns
        if column
        not in (
            profile_group
            + integer_like_columns
        )
    ]

    profiles[
        float_columns
    ] = (
        profiles[
            float_columns
        ]
        .round(2)
    )

    return profiles


# ==========================================================
# VALIDATION SUMMARY
# ==========================================================

def print_validation_summary(
    monthly_history: pd.DataFrame,
    seasonal_profiles: pd.DataFrame,
):
    print()
    print("=" * 70)
    print("MONTHLY FORECAST HISTORY BUILD COMPLETE")
    print("=" * 70)

    print(
        "Historical monthly rows:",
        len(monthly_history)
    )

    print(
        "Seasonal profile rows:",
        len(seasonal_profiles)
    )

    print(
        "Stores:",
        seasonal_profiles[
            "store_id"
        ].nunique()
    )

    print(
        "Categories:",
        seasonal_profiles[
            "category"
        ].nunique()
    )

    print(
        "Brands:",
        seasonal_profiles[
            "brand"
        ].nunique()
    )

    print(
        "Genders:",
        seasonal_profiles[
            "gender"
        ].nunique()
    )

    print(
        "Calendar months:",
        sorted(
            seasonal_profiles[
                "month"
            ].unique()
            .tolist()
        )
    )

    print()

    print(
        "Missing values in seasonal profiles:"
    )

    missing = (
        seasonal_profiles
        .isna()
        .sum()
    )

    missing = missing[
        missing > 0
    ]

    if missing.empty:
        print("None")
    else:
        print(
            missing.to_string()
        )

    print("=" * 70)


# ==========================================================
# MAIN
# ==========================================================

def main():
    parser = argparse.ArgumentParser(
        description=(
            "Build compact monthly forecast "
            "history and seasonal profiles "
            "from the original training data."
        )
    )

    parser.add_argument(
        "--sales",
        default=str(
            BASE_DIR
            / "scripts"
            / "data"
            / "sales.csv"
        ),
        help="Path to historical sales CSV."
    )

    parser.add_argument(
        "--products",
        default=str(
            BASE_DIR
            / "scripts"
            / "data"
            / "products.csv"
        ),
        help="Path to products CSV."
    )

    parser.add_argument(
        "--events",
        default=str(
            BASE_DIR
            / "scripts"
            / "data"
            / "events.csv"
        ),
        help="Path to events CSV."
    )

    parser.add_argument(
        "--promotions",
        default=str(
            BASE_DIR
            / "scripts"
            / "data"
            / "promotions.csv"
        ),
        help="Path to promotions CSV."
    )

    parser.add_argument(
        "--output-dir",
        default=str(
            DEFAULT_OUTPUT_DIR
        ),
        help=(
            "Directory for generated "
            "history/profile CSV files."
        ),
    )

    args = parser.parse_args()

    sales_path = Path(
        args.sales
    )

    products_path = Path(
        args.products
    )

    events_path = Path(
        args.events
    )

    promotions_path = Path(
        args.promotions
    )

    output_dir = Path(
        args.output_dir
    )

    for path in [
        sales_path,
        products_path,
        events_path,
        promotions_path,
    ]:
        if not path.exists():
            raise FileNotFoundError(
                f"File not found: {path}"
            )

    output_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    (
        sales,
        products,
        events,
        promotions,
    ) = load_training_data(
        sales_path,
        products_path,
        events_path,
        promotions_path,
    )

    (
        sales,
        events,
        promotions,
    ) = prepare_dates(
        sales,
        events,
        promotions,
    )

    monthly_history = (
        build_monthly_history(
            sales,
            products,
            events,
            promotions,
        )
    )

    seasonal_profiles = (
        build_seasonal_profiles(
            monthly_history
        )
    )

    history_output = (
        output_dir
        / "monthly_forecast_history.csv"
    )

    profile_output = (
        output_dir
        / "monthly_forecast_profiles.csv"
    )

    monthly_history.to_csv(
        history_output,
        index=False,
    )

    seasonal_profiles.to_csv(
        profile_output,
        index=False,
    )

    print_validation_summary(
        monthly_history,
        seasonal_profiles,
    )

    print(
        "\nDetailed history saved to:"
    )

    print(
        history_output.resolve()
    )

    print(
        "\nCompact runtime profiles saved to:"
    )

    print(
        profile_output.resolve()
    )


if __name__ == "__main__":
    main()