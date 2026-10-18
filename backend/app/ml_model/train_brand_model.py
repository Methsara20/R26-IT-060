import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score
import pickle
import os

def train_model():
    print("Loading dataset...")
    base_dir = os.path.dirname(__file__)
    data_path = os.path.join(base_dir, 'brand_sizing_dataset.csv')
    df = pd.read_csv(data_path)

    # We need separate encoders for each categorical feature
    encoders = {
        'standard_size': LabelEncoder(),
        'brand': LabelEncoder(),
        'category': LabelEncoder(),
        'brand_specific_size': LabelEncoder()
    }

    # Fit and transform
    X = pd.DataFrame()
    X['standard_size'] = encoders['standard_size'].fit_transform(df['standard_size'])
    X['brand'] = encoders['brand'].fit_transform(df['brand'])
    X['category'] = encoders['category'].fit_transform(df['category'])
    
    y = encoders['brand_specific_size'].fit_transform(df['brand_specific_size'])

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    print("Training RandomForestClassifier...")
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    
    print(f"========================================")
    print(f"🎯 Model Accuracy: {accuracy * 100:.2f}%")
    print(f"========================================")

    # Save the model
    model_path = os.path.join(base_dir, 'brand_sizing_model.pkl')
    with open(model_path, 'wb') as f:
        pickle.dump(model, f)
        
    # Save the encoders
    encoders_path = os.path.join(base_dir, 'brand_sizing_encoders.pkl')
    with open(encoders_path, 'wb') as f:
        pickle.dump(encoders, f)

    print(f"Saved model to {model_path}")
    print(f"Saved encoders to {encoders_path}")

if __name__ == "__main__":
    train_model()
