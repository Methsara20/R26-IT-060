import time
from typing import Any, Optional

class SimpleTTLCache:
    def __init__(self, ttl_seconds: int = 300):
        self.ttl = ttl_seconds
        self.cache = {}
        
    def get(self, key: str) -> Optional[Any]:
        if key in self.cache:
            value, timestamp = self.cache[key]
            if time.time() - timestamp < self.ttl:
                return value
            else:
                del self.cache[key]
        return None
        
    def set(self, key: str, value: Any):
        self.cache[key] = (value, time.time())
        
    def clear(self):
        self.cache = {}

# Product catalog rarely changes, cache for 5 minutes
products_cache = SimpleTTLCache(ttl_seconds=300)

# User profiles (height, weight, etc.) change infrequently, cache for 10 minutes
profiles_cache = SimpleTTLCache(ttl_seconds=600)

# Zone configurations (name, capacity) change rarely, cache for 5 minutes
zones_cache = SimpleTTLCache(ttl_seconds=300)


