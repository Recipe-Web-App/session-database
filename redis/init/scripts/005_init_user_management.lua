-- Initialize User Management Database (DB 4)
-- User data cache for user management service

local config_key = "user_config"
local stats_key = "user_stats"
local patterns_key = "user_key_patterns"

-- Initialize configuration
redis.call("HSET", config_key,
    "database", 4,
    "service", "user-management",
    "purpose", "user-cache",
    "default_ttl", 3600,           -- 1 hour
    "profile_ttl", 86400,          -- 24 hours
    "preferences_ttl", 3600,       -- 1 hour
    "max_entries", 50000,
    "initialized_at", redis.call("TIME")[1]
)

-- Initialize statistics
redis.call("HSET", stats_key,
    "total_users_cached", 0,
    "active_cache_entries", 0,
    "cache_hits", 0,
    "cache_misses", 0,
    "cache_updates", 0,
    "cache_invalidations", 0,
    "last_cleanup", 0
)

-- Document key patterns
redis.call("HSET", patterns_key,
    "profile", "user:profile:*",
    "preferences", "user:preferences:*",
    "settings", "user:settings:*",
    "recent_activity", "user:activity:*"
)

return {ok = "User management cache initialized in DB 4"}
