-- Initialize session cleanup mechanisms
-- This script sets up automatic cleanup of expired sessions

local session_cleanup_key = "session_cleanup"
local session_prefix = "session:"
local user_sessions_prefix = "user_sessions:"
local session_stats_key = "session_stats"
local refresh_token_cleanup_key = "refresh_token_cleanup"
local refresh_token_prefix = "refresh_token:"
local user_refresh_tokens_prefix = "user_refresh_tokens:"

-- Function to cleanup expired sessions
local function cleanup_expired_sessions()
    local current_time = redis.call("TIME")[1]
    local expired_sessions = redis.call("ZRANGEBYSCORE", session_cleanup_key, 0, current_time)
    local cleaned_count = 0

    for i, session_id in ipairs(expired_sessions) do
        local session_key = session_prefix .. session_id

        -- Get session data to find user_id
        local session_data = redis.call("GET", session_key)
        if session_data then
            -- Parse session data to get user_id (assuming JSON format)
            -- This is a simplified version - in practice, you'd parse the JSON
            local user_id = "unknown" -- Would be extracted from session_data

            -- Remove session from user's sessions set
            local user_sessions_key = user_sessions_prefix .. user_id
            redis.call("SREM", user_sessions_key, session_id)

            -- Delete the session
            redis.call("DEL", session_key)
            cleaned_count = cleaned_count + 1
        end

        -- Remove from cleanup set
        redis.call("ZREM", session_cleanup_key, session_id)
    end

    -- Update statistics
    if cleaned_count > 0 then
        redis.call("HINCRBY", session_stats_key, "expired_sessions", cleaned_count)
        redis.call("HSET", session_stats_key, "last_cleanup", current_time)
    end

    return cleaned_count
end

-- Function to cleanup expired refresh tokens
local function cleanup_expired_refresh_tokens()
    local current_time = redis.call("TIME")[1]
    local expired_refresh_tokens = redis.call("ZRANGEBYSCORE", refresh_token_cleanup_key, 0, current_time)
    local cleaned_count = 0

    for i, refresh_token_id in ipairs(expired_refresh_tokens) do
        local refresh_token_key = refresh_token_prefix .. refresh_token_id

        -- Get refresh token data to find user_id
        local refresh_token_data = redis.call("GET", refresh_token_key)
        if refresh_token_data then
            -- Parse refresh token data to get user_id (assuming JSON format)
            -- This is a simplified version - in practice, you'd parse the JSON
            local user_id = "unknown" -- Would be extracted from refresh_token_data

            -- Remove refresh token from user's refresh tokens set
            local user_refresh_tokens_key = user_refresh_tokens_prefix .. user_id
            redis.call("SREM", user_refresh_tokens_key, refresh_token_id)

            -- Delete the refresh token
            redis.call("DEL", refresh_token_key)
            cleaned_count = cleaned_count + 1
        end

        -- Remove from cleanup set
        redis.call("ZREM", refresh_token_cleanup_key, refresh_token_id)
    end

    -- Update statistics
    if cleaned_count > 0 then
        redis.call("HINCRBY", session_stats_key, "expired_refresh_tokens", cleaned_count)
        redis.call("HSET", session_stats_key, "last_cleanup", current_time)
    end

    return cleaned_count
end

-- Function to get cleanup statistics
local function get_cleanup_stats()
    local stats = redis.call("HGETALL", session_stats_key)
    local result = {}

    for i = 1, #stats, 2 do
        result[stats[i]] = stats[i + 1]
    end

    return result
end

-- Function to schedule cleanup
local function schedule_cleanup()
    -- This would typically be called by a cron job or timer
    local sessions_cleaned = cleanup_expired_sessions()
    local refresh_tokens_cleaned = cleanup_expired_refresh_tokens()
    return {sessions = sessions_cleaned, refresh_tokens = refresh_tokens_cleaned}
end

-- Initialize cleanup configuration
redis.call("HSET", "cleanup_config",
    "enabled", 1,
    "interval_seconds", 300,
    "batch_size", 100,
    "max_execution_time", 30
)

return {ok = "Session cleanup initialized successfully"}
