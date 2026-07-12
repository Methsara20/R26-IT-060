def get_zone_boundaries(points):
    latitudes = [point.latitude for point in points]
    longitudes = [point.longitude for point in points]
    altitudes = [point.altitude for point in points]

    return {
        "min_lat": min(latitudes),
        "max_lat": max(latitudes),
        "min_lon": min(longitudes),
        "max_lon": max(longitudes),
        "min_alt": min(altitudes),
        "max_alt": max(altitudes),
    }


def is_point_in_zone(latitude, longitude, altitude, zone, altitude_tolerance=30.0):
    in_lat = zone["min_lat"] <= latitude <= zone["max_lat"]
    in_lon = zone["min_lon"] <= longitude <= zone["max_lon"]
    # GPS altitude is unreliable indoors, so apply a tolerance buffer
    in_alt = (zone["min_alt"] - altitude_tolerance) <= altitude <= (zone["max_alt"] + altitude_tolerance)
    return in_lat and in_lon and in_alt