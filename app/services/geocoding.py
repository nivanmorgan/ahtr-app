"""
Geocoding service to convert location names into geographic coordinates.

Uses geopy with Nominatim (OpenStreetMap) as the default provider.
Includes error handling, rate limiting, and caching for production use.
"""
import logging
import time
import ssl
import certifi
from typing import Dict, List, Optional
import os

try:
    from geopy.geocoders import Nominatim
    from geopy.exc import GeocoderTimedOut, GeocoderServiceError
    GEOPY_AVAILABLE = True
except ImportError:
    GEOPY_AVAILABLE = False
    logging.warning("geopy not installed - geocoding will not work. Install with: pip install geopy")

logger = logging.getLogger(__name__)

# Simple in-memory cache for geocoded locations
_geocode_cache: Dict[str, Dict[str, Optional[float]]] = {}


def get_geolocator():
    """Get configured geolocator instance."""
    if not GEOPY_AVAILABLE:
        raise ImportError("geopy is not installed. Run: pip install geopy")
    
    user_agent = os.getenv("GEOCODING_USER_AGENT", "AHTR-Map-Service/1.0")
    
    # Create SSL context with certifi certificates for macOS compatibility
    ssl_context = ssl.create_default_context(cafile=certifi.where())
    
    return Nominatim(
        user_agent=user_agent,
        timeout=10,
        ssl_context=ssl_context
    )


def geocode_location(location_name: str, use_cache: bool = True) -> Dict[str, Optional[float]]:
    """
    Convert a location name to geographic coordinates.
    
    Args:
        location_name: Human-readable location (e.g., "Damascus, Syria")
        use_cache: Whether to use cached results
        
    Returns:
        Dict with 'latitude' and 'longitude' keys (values can be None if not found)
        
    Examples:
        >>> coords = geocode_location("Damascus, Syria")
        >>> print(coords)
        {'latitude': 33.5132, 'longitude': 36.2768}
    """
    if not location_name or not isinstance(location_name, str):
        logger.warning(f"Invalid location_name: {location_name}")
        return {'latitude': None, 'longitude': None}
    
    location_name = location_name.strip()
    
    # Check cache first
    if use_cache and location_name in _geocode_cache:
        logger.debug(f"Cache hit for location: {location_name}")
        return _geocode_cache[location_name]
    
    try:
        geolocator = get_geolocator()
        location = geolocator.geocode(location_name)
        
        if location:
            result = {
                'latitude': float(location.latitude),
                'longitude': float(location.longitude)
            }
            logger.info(f"Geocoded '{location_name}' -> lat: {result['latitude']}, lng: {result['longitude']}")
        else:
            result = {'latitude': None, 'longitude': None}
            logger.warning(f"No geocoding results found for: {location_name}")
        
        # Cache the result
        _geocode_cache[location_name] = result
        return result
        
    except GeocoderTimedOut:
        logger.error(f"Geocoding timeout for location: {location_name}")
        return {'latitude': None, 'longitude': None}
    
    except GeocoderServiceError as e:
        logger.error(f"Geocoding service error for {location_name}: {e}")
        return {'latitude': None, 'longitude': None}
    
    except Exception as e:
        logger.exception(f"Unexpected error geocoding {location_name}: {e}")
        return {'latitude': None, 'longitude': None}


def geocode_batch(
    locations: List[str], 
    rate_limit_delay: float = 1.0,
    progress_callback: Optional[callable] = None
) -> List[Dict[str, Optional[float]]]:
    """
    Geocode multiple locations with rate limiting.
    
    Args:
        locations: List of location names to geocode
        rate_limit_delay: Seconds to wait between requests (default 1.0 for Nominatim)
        progress_callback: Optional function called after each geocoding with (index, total)
        
    Returns:
        List of coordinate dicts in same order as input
        
    Example:
        >>> locations = ["Damascus, Syria", "Alexandria, Egypt", "Rome, Italy"]
        >>> results = geocode_batch(locations)
        >>> for loc, coords in zip(locations, results):
        ...     print(f"{loc}: {coords}")
    """
    results = []
    total = len(locations)
    
    for i, location_name in enumerate(locations, 1):
        coords = geocode_location(location_name)
        results.append(coords)
        
        if progress_callback:
            progress_callback(i, total)
        
        # Rate limit: wait between requests (except for last one)
        if i < total:
            time.sleep(rate_limit_delay)
    
    return results


def clear_cache():
    """Clear the geocoding cache. Useful for testing or forcing fresh lookups."""
    global _geocode_cache
    _geocode_cache = {}
    logger.info("Geocoding cache cleared")


def get_cache_stats() -> Dict[str, int]:
    """Get statistics about the geocoding cache."""
    return {
        'total_cached': len(_geocode_cache),
        'with_coordinates': sum(1 for v in _geocode_cache.values() if v['latitude'] is not None)
    }
