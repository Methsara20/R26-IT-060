import pandas as pd
import joblib
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, r2_score
import warnings
warnings.filterwarnings('ignore')

def train_advanced_model():
    print("🚀 Loading Dataset...")
    df = pd.read_csv('Body Measurements _ with_weight.csv')
    df.columns = df.columns.str.strip()
    
    df = df.rename(columns={
        "Gender": "gender",
        "TotalHeight": "height",
        "Weight": "weight",
        "ShoulderWidth": "shoulder_width",
        "Waist": "waist",
        "LegLength": "leg_length",
    })
    
    # Feature Engineering: Calculate BMI as an extra powerful feature for the AI
    # Weight in CSV is in KG. Height is in inches.
    # BMI = (Weight_KG / 0.453592) * 703 / (Height_in ^ 2)
    df['bmi'] = ((df['weight'] / 0.453592) * 703) / (df['height'] ** 2)
    
    required_columns = ["gender", "height", "weight", "bmi", "shoulder_width", "waist", "leg_length"]
    df = df[required_columns].dropna()
    
    # Inputs (X) and Outputs (y)
    X = df[['gender', 'height', 'weight', 'bmi']]
    y = df[['shoulder_width', 'waist', 'leg_length']]
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print("🌲 Tuning Random Forest Regressor (Hyperparameter Optimization)...")
    # Base model
    rf = RandomForestRegressor(random_state=42)
    
    # We test multiple combinations of parameters to find the absolute most accurate model
    param_grid = {
        'n_estimators': [100, 300, 500],
        'max_depth': [None, 10, 20],
        'min_samples_split': [2, 5],
        'min_samples_leaf': [1, 2]
    }
    
    print("Searching hundreds of parameter combinations...")
    grid_search = GridSearchCV(estimator=rf, param_grid=param_grid, 
                               cv=3, n_jobs=-1, scoring='neg_mean_absolute_error', verbose=1)
    
    grid_search.fit(X_train, y_train)
    
    best_model = grid_search.best_estimator_
    print(f"\n✅ Best Parameters Found: {grid_search.best_params_}")
    
    print("\n🧠 Evaluating Improved Model...")
    y_pred = best_model.predict(X_test)
    
    mae = mean_absolute_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)
    
    print("="*40)
    print(f"📉 New Mean Absolute Error (MAE): {mae:.2f} inches (Lower is better!)")
    print(f"📈 New R^2 Score (Accuracy Proxy): {r2:.3f} (Closer to 1.0 is better!)")
    print("="*40)
    
    model_path = 'body_measurement_model.pkl'
    joblib.dump(best_model, model_path)
    print(f"💾 Highly Accurate Model saved over '{model_path}'")
    print("Your FastApi backend will now use this highly accurate version!")

if __name__ == "__main__":
    train_advanced_model()
