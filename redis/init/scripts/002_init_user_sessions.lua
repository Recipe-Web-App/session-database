-- Initialize user session tracking structures
-- This script sets up the Redis structures for tracking user sessions

local user_sessions_prefix = "user_sessions:"
local session_prefix = "session:"
local user_stats_prefix = "user_stats:"
local refresh_token_prefix = "refresh_token:"
local user_refresh_tokens_prefix = "user_refresh_tokens:"

-- Function to initialize user session tracking
local function init_user_session_tracking(user_id)
    local user_sessions_key = user_sessions_prefix .. user_id
    local user_stats_key = user_stats_prefix .. user_id
    local user_refresh_tokens_key = user_refresh_tokens_prefix .. user_id

    -- Initialize user sessions set if it doesn't exist
    if redis.call("EXISTS", user_sessions_key) == 0 then
        redis.call("DEL", user_sessions_key)
    end

    -- Initialize user refresh tokens set if it doesn't exist
    if redis.call("EXISTS", user_refresh_tokens_key) == 0 then
        redis.call("DEL", user_refresh_tokens_key)
    end

    -- Initialize user statistics if they don't exist
    if redis.call("EXISTS", user_stats_key) == 0 then
        redis.call("HSET", user_stats_key,
            "total_sessions", 0,
            "active_sessions", 0,
            "total_refresh_tokens", 0,
            "active_refresh_tokens", 0,
            "last_login", 0,
            "created_at", redis.call("TIME")[1]
        )
    end

    return true
end

-- Function to get user session count
local function get_user_session_count(user_id)
    local user_sessions_key = user_sessions_prefix .. user_id
    return redis.call("SCARD", user_sessions_key)
end

-- Function to get user refresh token count
local function get_user_refresh_token_count(user_id)
    local user_refresh_tokens_key = user_refresh_tokens_prefix .. user_id
    return redis.call("SCARD", user_refresh_tokens_key)
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

-- Function to get user active refresh tokens
local function get_user_active_refresh_tokens(user_id)
    local user_refresh_tokens_key = user_refresh_tokens_prefix .. user_id
    local refresh_token_ids = redis.call("SMEMBERS", user_refresh_tokens_key)
    local active_refresh_tokens = {}

    for i, refresh_token_id in ipairs(refresh_token_ids) do
        local refresh_token_key = refresh_token_prefix .. refresh_token_id
        if redis.call("EXISTS", refresh_token_key) == 1 then
            table.insert(active_refresh_tokens, refresh_token_id)
        else
            -- Remove expired refresh token from user's set
            redis.call("SREM", user_refresh_tokens_key, refresh_token_id)
        end
    end

    return active_refresh_tokens
end

-- Export functions for use in other scripts
redis.call("SET", "user_session_functions_loaded", "true")

return {ok = "User session tracking initialized successfully"}
