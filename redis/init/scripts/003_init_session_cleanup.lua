-- Initialize session cleanup mechanisms
-- This script sets up automatic cleanup of expired sessions

local session_cleanup_key = "session_cleanup"
local session_prefix = "session:"
local user_sessions_prefix = "user_sessions:"
local session_stats_key = "session_stats"

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
    local cleaned = cleanup_expired_sessions()
    print("Cleaned up " .. cleaned .. " expired sessions")
    return cleaned
end

-- Initialize cleanup configuration
redis.call("HSET", "cleanup_config",
    "enabled", 1,
    "interval_seconds", 300,
    "batch_size", 100,
    "max_execution_time", 30
)

print("Session cleanup initialization completed")
return {ok = "Session cleanup initialized successfully"}
