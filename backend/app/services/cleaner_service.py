"""
backend/cleaner_service.py
Same data cleaning logic as shared/cleaner.py in the Streamlit app —
duplicate removal, PII stripping, date/numeric coercion — ported here
without any Streamlit dependency, for the FastAPI upload endpoint.
"""

import pandas as pd

PII_COLUMNS = ["phone", "email", "dob", "mobile", "telephone", "address", "name", "nic"]


def clean_csv(df: pd.DataFrame, file_type: str = "transactions"):
    report = []
    original_rows = len(df)
    df.columns = [c.lower().strip().replace(" ", "_") for c in df.columns]

    dupes = df.duplicated().sum()
    if dupes > 0:
        df = df.drop_duplicates()
        report.append(f"Removed {dupes} duplicate rows")

    pii_found = [c for c in df.columns if any(p in c for p in PII_COLUMNS)]
    if pii_found:
        df = df.drop(columns=pii_found)
        report.append(f"Anonymized {len(pii_found)} PII columns: {', '.join(pii_found)}")

    # Only match real date/time columns, not numeric "days_since_..." style columns.
    date_cols = [c for c in df.columns if any(k in c for k in ["date", "time"])
                 or c.endswith("_day") or c == "day"]
    for col in date_cols:
        try:
            df[col] = pd.to_datetime(df[col], errors="coerce")
            bad_dates = df[col].isna().sum()
            if bad_dates > 0:
                df[col] = df[col].ffill()
                report.append(f"Fixed {bad_dates} invalid dates in '{col}'")
        except Exception:
            pass

    num_cols = [c for c in df.columns if any(k in c for k in
                ["amount", "price", "lkr", "points", "balance", "score",
                 "quantity", "pct", "frequency", "age", "discount",
                 "days_since", "spend"])]
    for col in num_cols:
        if df[col].dtype == object:
            df[col] = pd.to_numeric(
                df[col].astype(str).str.replace(",", "").str.replace("LKR", "").str.strip(),
                errors="coerce")
            nulls = df[col].isna().sum()
            if nulls > 0:
                df[col] = df[col].fillna(df[col].median())
                report.append(f"Fixed {nulls} invalid values in '{col}'")

    cat_cols = [c for c in df.columns if df[c].dtype == object]
    for col in cat_cols:
        df[col] = df[col].astype(str).str.strip().str.title()

    empty = df.isna().all(axis=1).sum()
    if empty > 0:
        df = df.dropna(how="all")
        report.append(f"Removed {empty} empty rows")

    final_rows = len(df)
    if original_rows == final_rows and not report:
        report.append("Data is clean — no issues found")
    else:
        report.append(f"Final dataset: {final_rows} rows ready for analysis")

    return df, report