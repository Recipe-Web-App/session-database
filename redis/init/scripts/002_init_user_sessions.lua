-- Initialize user session tracking structures
-- This script sets up the Redis structures for tracking user sessions

local user_sessions_prefix = "user_sessions:"
local session_prefix = "session:"
local user_stats_prefix = "user_stats:"

-- Function to initialize user session tracking
local function init_user_session_tracking(user_id)
    local user_sessions_key = user_sessions_prefix .. user_id
    local user_stats_key = user_stats_prefix .. user_id

    -- Initialize user sessions set if it doesn't exist
    if redis.call("EXISTS", user_sessions_key) == 0 then
        redis.call("DEL", user_sessions_key)
        print("Initialized user sessions set for user: " .. user_id)
    end

    -- Initialize user statistics if they don't exist
    if redis.call("EXISTS", user_stats_key) == 0 then
        redis.call("HSET", user_stats_key,
            "total_sessions", 0,
            "active_sessions", 0,
            "last_login", 0,
            "created_at", redis.call("TIME")[1]
        )
        print("Initialized user statistics for user: " .. user_id)
    end

    return true
end

-- Function to get user session count
local function get_user_session_count(user_id)
    local user_sessions_key = user_sessions_prefix .. user_id
    return redis.call("SCARD", user_sessions_key)
end

-- Function to get user active sessions
local function get_user_active_sessions(user_id)
    local user_sessions_key = user_sessions_prefix .. user_id
    local session_ids = redis.call("SMEMBERS", user_sessions_key)
    local active_sessions = {}

    for i, session_id in ipairs(session_ids) do
        local session_key = session_prefix .. session_id
        if redis.call("EXISTS", session_key) == 1 then
            table.insert(active_sessions, session_id)
        else
            -- Remove expired session from user's set
            redis.call("SREM", user_sessions_key, session_id)
        end
    end

    return active_sessions
end

-- Export functions for use in other scripts
redis.call("SET", "user_session_functions_loaded", "true")

print("User session tracking initialization completed")
return {ok = "User session tracking initialized successfully"}
