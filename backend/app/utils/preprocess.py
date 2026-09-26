import pandas as pd
import json

def load_columns(path):
    with open(path, "r") as f:
        return json.load(f)

def preprocess_input(data, columns):
    df = pd.DataFrame([data])

    # one-hot encoding
    df = pd.get_dummies(df)

    # add missing columns
    for col in columns:
        if col not in df.columns:
            df[col] = 0

    # ensure correct order
    df = df[columns]

    return df