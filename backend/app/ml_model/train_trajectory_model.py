import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
import pickle
import os

def train_intent_model():
    print("🚀 Loading dataset...")
    # Load the synthetic dataset we just generated
    df = pd.read_csv('customer_tracking_dataset.csv')
    
    # Split the data into Features (X) and Label (y)
    # We drop 'intent_class' from X because it's the answer key
    X = df.drop(columns=['intent_class'])
    y = df['intent_class']
    
    # Split into 80% training data and 20% testing data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print("🌲 Initializing Random Forest Classifier...")
    # Initialize the Random Forest model
    rf_model = RandomForestClassifier(n_estimators=100, random_state=42)
    
    print("🧠 Training the model (this might take a second)...")
    # Train the model
    rf_model.fit(X_train, y_train)
    
    # Test the model
    y_pred = rf_model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    
    print("\n" + "="*30)
    print(f"✅ MODEL TRAINING COMPLETE")
    print(f"🎯 Accuracy: {accuracy * 100:.2f}%")
    print("="*30 + "\n")
    
    print("📊 Classification Report:")
    print(classification_report(y_test, y_pred))
    
    print("🔍 Feature Importance (What matters most?):")
    # Get importance of each feature
    importances = rf_model.feature_importances_
    feature_names = X.columns
    for name, importance in zip(feature_names, importances):
        print(f" - {name}: {importance * 100:.1f}%")
        
    # Save the trained model to a file so the backend API can use it
    model_filename = 'trajectory_intent_model.pkl'
    with open(model_filename, 'wb') as file:
        pickle.dump(rf_model, file)
        
    print(f"\n💾 Model successfully saved as '{model_filename}'")
    print("This file can now be loaded into trajectory_service.py for real-time predictions!")

if __name__ == "__main__":
    train_intent_model()
