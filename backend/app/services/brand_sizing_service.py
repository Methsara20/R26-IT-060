import os
import pickle
import pandas as pd

_model = None
_encoders = None

def load_brand_sizing_model():
    global _model, _encoders
    if _model is not None and _encoders is not None:
        return

    base_dir = os.path.dirname(os.path.dirname(__file__))
    model_path = os.path.join(base_dir, 'ml_model', 'brand_sizing_model.pkl')
    encoders_path = os.path.join(base_dir, 'ml_model', 'brand_sizing_encoders.pkl')

    with open(model_path, 'rb') as f:
        _model = pickle.load(f)

    with open(encoders_path, 'rb') as f:
        _encoders = pickle.load(f)

def predict_brand_specific_size(standard_size: str, brand: str, category: str) -> str:
    load_brand_sizing_model()

    # Preprocess inputs
    try:
        # Handle unseen labels by falling back (if necessary, though our dataset has all current brands)
        encoded_standard = _encoders['standard_size'].transform([standard_size])[0]
        encoded_brand = _encoders['brand'].transform([brand])[0]
        
        # Default category to 'clothing' if unseen (e.g. some random string)
        try:
            encoded_category = _encoders['category'].transform([category])[0]
        except ValueError:
            encoded_category = _encoders['category'].transform(['clothing'])[0]

        X = pd.DataFrame({
            'standard_size': [encoded_standard],
            'brand': [encoded_brand],
            'category': [encoded_category]
        })

        prediction = _model.predict(X)[0]
        decoded_size = _encoders['brand_specific_size'].inverse_transform([prediction])[0]
        
        return decoded_size
    except Exception as e:
        print(f"Error predicting brand size: {e}")
        return standard_size # fallback to standard size
