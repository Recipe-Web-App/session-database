-- Initialize session-related Redis keys and data structures
-- This script sets up the basic Redis structure for session management

local session_cleanup_key = "session_cleanup"
local session_prefix = "session:"
local user_sessions_prefix = "user_sessions:"
local session_stats_key = "session_stats"

-- Initialize session cleanup sorted set if it doesn't exist
if redis.call("EXISTS", session_cleanup_key) == 0 then
    redis.call("DEL", session_cleanup_key)
    print("Initialized session cleanup sorted set")
end

-- Initialize session statistics hash if it doesn't exist
if redis.call("EXISTS", session_stats_key) == 0 then
    redis.call("HSET", session_stats_key,
        "total_sessions", 0,
        "active_sessions", 0,
        "expired_sessions", 0,
        "last_cleanup", 0
    )
    print("Initialized session statistics")
end

-- Set up session configuration
redis.call("HSET", "session_config",
    "default_ttl", 3600,
    "max_sessions_per_user", 5,
    "cleanup_interval", 300
)

print("Session database initialization completed")
return {ok = "Session keys initialized successfully"}
