-- Initialize cache cleanup system for service cache (DB 1)
-- Simplified cleanup for basic TTL-based cache expiration

-- Switch to cache database (DB 1)
redis.call("SELECT", 1)

-- Initialize basic cleanup configuration
redis.call("HSET", "cache_cleanup_config",
    "cleanup_enabled", 1,
    "cleanup_interval_seconds", 600,  -- 10 minutes
    "last_cleanup_timestamp", 0
)

-- Initialize simple cleanup metrics (for monitoring script compatibility)
redis.call("HSET", "cache_cleanup_metrics",
    "total_cleanups_performed", 0,
    "total_entries_cleaned", 0,
    "last_cleanup_duration_ms", 0
)

return {ok = "Cache cleanup system initialized successfully in DB 1 (simplified)"}
