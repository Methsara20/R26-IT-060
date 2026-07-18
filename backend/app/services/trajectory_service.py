import math

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

def classify_intent(distance_meters: float, elapsed_seconds: float, speed_threshold: float = 0.5) -> str:
    """
    Classify the customer's intent based on their velocity.
    speed_threshold: meters per second. 0.5 m/s is roughly 1.8 km/h.
    """
    if elapsed_seconds <= 0:
        return "Unknown"
        
    speed = distance_meters / elapsed_seconds
    
    if speed > speed_threshold:
        return "Transiting"
    else:
        return "Browsing"
