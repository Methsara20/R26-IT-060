import math
import os
import pickle
import pandas as pd

# Load the ML model once when the service is imported
MODEL_PATH = os.path.join(os.path.dirname(__file__), '..', 'ml_model', 'trajectory_intent_model.pkl')
try:
    with open(MODEL_PATH, 'rb') as f:
        intent_model = pickle.load(f)
except Exception as e:
    print(f"Warning: Could not load trajectory ML model. Falling back to rule-based. Error: {e}")
    intent_model = None

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great circle distance in meters between two points 
    on the earth (specified in decimal degrees) using Haversine formula.
    """
    # Convert decimal degrees to radians 
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])

    # Haversine formula 
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a)) 
    
    # Radius of earth in meters (approx 6371 km)
    r = 6371000 
    return c * r

def classify_intent(distance_meters: float, elapsed_seconds: float, zone_dwell_time_seconds: float = 0.0, speed_threshold: float = 0.5) -> str:
    """
    Classify the customer's intent using the trained Machine Learning model.
    Falls back to a speed threshold rule if the model fails to load.
    """
    if elapsed_seconds <= 0:
        return "Unknown"
        
    speed = distance_meters / elapsed_seconds
    
    if intent_model is not None:
        try:
            # In a real system, we would calculate actual direction change using a history of 3 points.
            # Since we only store 2 points right now, we simulate the turning metric.
            direction_change = 90.0 if speed < 0.45 else 5.0 
            
            features = pd.DataFrame([{
                'distance_moved_meters': distance_meters,
                'time_elapsed_seconds': elapsed_seconds,
                'velocity_mps': speed,
                'direction_change_degrees': direction_change,
                'zone_dwell_time_seconds': zone_dwell_time_seconds
            }])
            
            prediction = intent_model.predict(features)[0]
            return prediction
        except Exception as e:
            print(f"ML Prediction failed, using fallback: {e}")
            pass

    # Fallback to standard rule-based logic
    if speed > speed_threshold:
        return "Transiting"
    else:
        return "Browsing"
