-- Initialize session-related Redis keys and data structures
-- This script sets up the basic Redis structure for session management

local session_cleanup_key = "session_cleanup"
local session_prefix = "session:"
local user_sessions_prefix = "user_sessions:"
local session_stats_key = "session_stats"
local refresh_token_prefix = "refresh_token:"
local refresh_token_cleanup_key = "refresh_token_cleanup"

-- Initialize session cleanup sorted set if it doesn't exist
if redis.call("EXISTS", session_cleanup_key) == 0 then
    redis.call("DEL", session_cleanup_key)
end

-- Initialize refresh token cleanup sorted set if it doesn't exist
if redis.call("EXISTS", refresh_token_cleanup_key) == 0 then
    redis.call("DEL", refresh_token_cleanup_key)
end

-- Initialize session statistics hash if it doesn't exist
if redis.call("EXISTS", session_stats_key) == 0 then
    redis.call("HSET", session_stats_key,
        "total_sessions", 0,
        "active_sessions", 0,
        "expired_sessions", 0,
        "total_refresh_tokens", 0,
        "active_refresh_tokens", 0,
        "expired_refresh_tokens", 0,
        "last_cleanup", 0
    )
end

-- Set up session configuration
redis.call("HSET", "session_config",
    "default_ttl", 3600,
    "refresh_token_ttl", 604800,  -- 7 days
    "max_sessions_per_user", 5,
    "max_refresh_tokens_per_user", 3,
    "cleanup_interval", 300
)

return {ok = "Session keys initialized successfully"}
