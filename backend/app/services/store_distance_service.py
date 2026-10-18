from app.services.firebase_service import (
    get_all_documents
)

from app.constants.collections import (
    STORE_DISTANCES_COLLECTION
)


_distance_cache = None


def get_all_store_distances(force_refresh: bool = False):
    """
    Load all store distances from Firestore.
    Uses in-memory cache to minimize Firestore reads.
    """

    global _distance_cache

    if _distance_cache is None or force_refresh:
        print("Loading store distances from Firestore...")

        _distance_cache = get_all_documents(
            STORE_DISTANCES_COLLECTION
        )

    return _distance_cache


def clear_store_distance_cache():
    global _distance_cache
    _distance_cache = None


def get_distance_between_stores(
    from_store: str,
    to_store: str
):
    """
    Returns the distance document.

    Since only one direction is stored,
    automatically checks both directions.

    Example:

    CP001 -> CP003

    or

    CP003 -> CP001
    """

    if from_store == to_store:
        return {
            "distance_km": 0,
            "estimated_time_minutes": 0,
            "estimated_transfer_cost": 0,
            "route_type": "Same Store"
        }

    distances = get_all_store_distances()

    for item in distances:

        if (
            item.get("from_store") == from_store
            and
            item.get("to_store") == to_store
        ):
            return item

        if (
            item.get("from_store") == to_store
            and
            item.get("to_store") == from_store
        ):
            return item

    return None


def get_distance_km(
    from_store: str,
    to_store: str
):
    result = get_distance_between_stores(
        from_store,
        to_store
    )

    if result is None:
        return None

    return float(
        result.get("distance_km", 0)
    )


def get_estimated_time(
    from_store: str,
    to_store: str
):
    result = get_distance_between_stores(
        from_store,
        to_store
    )

    if result is None:
        return None

    return int(
        result.get(
            "estimated_time_minutes",
            0
        )
    )


def get_transfer_cost(
    from_store: str,
    to_store: str
):
    """
    Dynamic transport cost.

    Can later be replaced by
    system_settings collection.
    """

    result = get_distance_between_stores(
        from_store,
        to_store
    )

    if result is None:
        return None

    distance = float(
        result.get(
            "distance_km",
            0
        )
    )

    cost_per_km = float(
        result.get(
            "transport_cost_per_km",
            200
        )
    )

    return round(
        distance * cost_per_km,
        2
    )


def get_route_information(
    from_store: str,
    to_store: str
):
    """
    Complete route information.

    Recommended function to use.
    """

    result = get_distance_between_stores(
        from_store,
        to_store
    )

    if result is None:
        return None

    return {

        "distance_km":
            float(result.get(
                "distance_km",
                0
            )),

        "estimated_time_minutes":
            int(result.get(
                "estimated_time_minutes",
                0
            )),

        "transport_cost_per_km":
            float(result.get(
                "transport_cost_per_km",
                200
            )),

        "estimated_transfer_cost":
            round(
                float(result.get(
                    "distance_km",
                    0
                ))
                *
                float(result.get(
                    "transport_cost_per_km",
                    200
                )),
                2
            ),

        "route_type":
            result.get(
                "route_type",
                "Road"
            )
    }