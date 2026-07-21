from math import radians, sin, cos, sqrt, atan2


def is_within_radius(user_lat, user_lon, target_lat, target_lon, radius_meters):
    """
    Check if the user is within a certain radius of the target location.

    Args:
        user_lat (float): Latitude of the user's location.
        user_lon (float): Longitude of the user's location.
        target_lat (float): Latitude of the target location.
        target_lon (float): Longitude of the target location.
        radius_meters (float): Radius in meters.

    Returns:
        bool: True if the user is within the radius, False otherwise.
    """
    # Radius of the Earth in meters
    EARTH_RADIUS = 6371000

    # Convert latitude and longitude from degrees to radians
    user_lat, user_lon = radians(user_lat), radians(user_lon)
    target_lat, target_lon = radians(target_lat), radians(target_lon)

    # Differences in coordinates
    delta_lat = target_lat - user_lat
    delta_lon = target_lon - user_lon

    # Haversine formula
    a = sin(delta_lat / 2)**2 + cos(user_lat) * \
        cos(target_lat) * sin(delta_lon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    # Distance in meters
    distance = EARTH_RADIUS * c

    return distance <= radius_meters


# Example usage:
user_latitude = 27.683892873029084
user_longitude = 85.33618472863539  # Example: User's longitude
target_latitude = 27.683790760290307  # Example: Target latitude
target_longitude = 85.33621860988507  # Example: Target longitude
radius = 50

if is_within_radius(user_latitude, user_longitude, target_latitude, target_longitude, radius):
    print("User is within the radius!")
else:
    print("User is outside the radius.")
