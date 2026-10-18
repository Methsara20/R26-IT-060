"""
train_model.py
Trains the XGBoost Promotion Recommender on the enriched, multi-year SkyHigh
retail dataset.

IMPORTANT DESIGN NOTE:
Earlier versions of this model tried to predict `offer_type` (which offer was
historically SENT to a customer) from customer attributes. That target is close
to randomly assigned in this dataset (offers were sent experimentally, for
treatment/control analysis) — so it can't be predicted well, no matter how many
features you add.

The real, usable signal in the data is REDEMPTION: whether a customer responds
to a given offer_type. So this version trains a model that predicts
P(redeemed=1 | customer attributes, offer_type, discount_pct, channel, timing),
and at inference time we score every offer_type for a given customer and
recommend the one with the highest predicted redemption probability.

Run this from your project root:
    python train_model.py
"""

import pandas as pd
import numpy as np
import json
import os
import pickle
from xgboost import XGBClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, roc_auc_score

# ── File location — single merged file, adjust if your filename differs ──
DATA_PATH = "app/data/Retail (Marketing Campaigns) Dataset.csv"
MODEL_OUT_PATH = "app/ml/model.pkl"
META_OUT_PATH  = "app/ml/columns.json"

# offer_type and discount_pct are INPUT features (not the target) — the
# model learns how redemption likelihood shifts across different offers per
# customer, which is what "recommend the best offer" actually needs.
CATEGORICAL_FEATURES = ["age_group", "gender", "loyalty_tier", "channel",
                         "preferred_category", "offer_type"]
NUMERIC_FEATURES = ["visit_frequency", "total_spend_lkr", "avg_basket_value_lkr",
                     "days_since_last_purchase", "customer_past_redemption_rate",
                     "discount_pct", "is_seasonal_window", "is_salary_cycle",
                     "is_school_holiday"]
FEATURES = CATEGORICAL_FEATURES + NUMERIC_FEATURES

TARGET = "redeemed"


def load_data():
    df = pd.read_csv(DATA_PATH)
    return df


def build_training_frame(df):
    # All required columns already live in the single merged file — no join needed.
    df = df.dropna(subset=FEATURES + [TARGET])
    return df


def encode_features(df):
    encoders = {}
    encoded_cols = []

    for feat in CATEGORICAL_FEATURES:
        classes = sorted(df[feat].astype(str).unique().tolist())
        encoders[feat] = classes
        class_to_idx = {c: i for i, c in enumerate(classes)}
        encoded_cols.append(df[feat].astype(str).map(class_to_idx).values)

    for feat in NUMERIC_FEATURES:
        encoded_cols.append(df[feat].astype(float).values)

    X = np.column_stack(encoded_cols)
    return X, encoders


def main():
    print("Loading data...")
    df_raw = load_data()
    print(f"  Total rows loaded: {len(df_raw):,}")

    print("Building training frame...")
    df = build_training_frame(df_raw)
    print(f"  Usable rows after dropna: {len(df):,}")

    print("Encoding features...")
    X, encoders = encode_features(df)
    y = df[TARGET].astype(int).values

    print(f"  Features used: {FEATURES}")
    print(f"  Target: {TARGET} (binary — will this customer redeem this offer?)")
    print(f"  Positive rate (baseline redemption rate): {y.mean()*100:.1f}%")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print("Training XGBoost classifier...")
    model = XGBClassifier(
        n_estimators=250,
        max_depth=5,
        learning_rate=0.08,
        subsample=0.9,
        colsample_bytree=0.9,
        random_state=42,
        eval_metric="logloss",
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]
    accuracy = accuracy_score(y_test, y_pred)
    auc = roc_auc_score(y_test, y_proba)
    print(f"\n✅ Model trained.")
    print(f"   Test accuracy: {accuracy*100:.1f}%")
    print(f"   Test ROC-AUC:  {auc:.3f}  (0.5 = random, 1.0 = perfect — better metric for imbalanced/binary tasks)")

    importances = model.feature_importances_
    feature_importance = {feat: float(round(imp, 4)) for feat, imp in zip(FEATURES, importances)}
    print("\nFeature importance:")
    for feat, imp in sorted(feature_importance.items(), key=lambda x: -x[1]):
        print(f"  {feat}: {imp}")

    os.makedirs("app/ml", exist_ok=True)
    with open(MODEL_OUT_PATH, "wb") as f:
        pickle.dump(model, f)

    meta = {
        "model_type": "redemption_probability",
        "features": FEATURES,
        "categorical_features": CATEGORICAL_FEATURES,
        "numeric_features": NUMERIC_FEATURES,
        "target": TARGET,
        "offer_types": encoders["offer_type"],
        "accuracy": float(round(accuracy, 4)),
        "roc_auc": float(round(auc, 4)),
        "baseline_redemption_rate": float(round(y.mean(), 4)),
        "feature_importance": feature_importance,
        "encoders": encoders,
        "training_rows": len(df),
    }
    with open(META_OUT_PATH, "w") as f:
        json.dump(meta, f, indent=2)

    print(f"\n✅ Saved model to {MODEL_OUT_PATH}")
    print(f"✅ Saved metadata to {META_OUT_PATH}")


if __name__ == "__main__":
    main()
