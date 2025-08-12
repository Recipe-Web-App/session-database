-- Initialize service cache Redis database (DB 1)
-- Simplified cache initialization for basic TTL-based caching

-- Switch to cache database (DB 1)
redis.call("SELECT", 1)

-- Set up basic cache configuration
redis.call("HSET", "cache_config",
    "default_ttl", 86400,  -- 24 hours (matches recipe scraper usage)
    "database", 1,
    "initialized_at", redis.call("TIME")[1]
)

-- Set up cache key patterns documentation (for monitoring script compatibility)
redis.call("HSET", "cache_key_patterns",
    "resource", "cache:resource:*"  -- For recipe scraper service
)

-- Initialize basic cache statistics (minimal for monitoring script)
redis.call("HSET", "cache_stats",
    "total_cache_entries", 0,
    "active_cache_entries", 0,
    "last_cleanup", 0
)

return {ok = "Service cache initialized successfully in DB 1 (simplified)"}
