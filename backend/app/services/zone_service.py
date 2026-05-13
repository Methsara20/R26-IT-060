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


def is_point_in_zone(latitude, longitude, altitude, zone):
    return (
        zone["min_lat"] <= latitude <= zone["max_lat"]
        and zone["min_lon"] <= longitude <= zone["max_lon"]
        and zone["min_alt"] <= altitude <= zone["max_alt"]
    )