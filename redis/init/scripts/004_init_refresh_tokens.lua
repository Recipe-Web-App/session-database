-- Initialize refresh token management structures
-- This script sets up the Redis structures for refresh token management

local refresh_token_prefix = "refresh_token:"
local user_refresh_tokens_prefix = "user_refresh_tokens:"
local refresh_token_cleanup_key = "refresh_token_cleanup"
local refresh_token_stats_key = "refresh_token_stats"

-- Function to store refresh token
local function store_refresh_token(refresh_token_id, user_id, token_data, ttl)
    local refresh_token_key = refresh_token_prefix .. refresh_token_id
    local user_refresh_tokens_key = user_refresh_tokens_prefix .. user_id

    -- Store the refresh token
    redis.call("SETEX", refresh_token_key, ttl, token_data)

    -- Add to user's refresh tokens set
    redis.call("SADD", user_refresh_tokens_key, refresh_token_id)

    -- Add to cleanup sorted set with expiration time
    local current_time = redis.call("TIME")[1]
    local expiration_time = current_time + ttl
    redis.call("ZADD", refresh_token_cleanup_key, expiration_time, refresh_token_id)

    -- Update statistics
    redis.call("HINCRBY", refresh_token_stats_key, "total_refresh_tokens", 1)
    redis.call("HINCRBY", refresh_token_stats_key, "active_refresh_tokens", 1)

    return true
end

-- Function to validate refresh token
local function validate_refresh_token(refresh_token_id)
    local refresh_token_key = refresh_token_prefix .. refresh_token_id

    if redis.call("EXISTS", refresh_token_key) == 1 then
        return redis.call("GET", refresh_token_key)
    else
        return nil
    end
end

-- Function to revoke refresh token
local function revoke_refresh_token(refresh_token_id, user_id)
    local refresh_token_key = refresh_token_prefix .. refresh_token_id
    local user_refresh_tokens_key = user_refresh_tokens_prefix .. user_id

    -- Remove from user's refresh tokens set
    redis.call("SREM", user_refresh_tokens_key, refresh_token_id)

    -- Remove from cleanup set
    redis.call("ZREM", refresh_token_cleanup_key, refresh_token_id)

    -- Delete the refresh token
    redis.call("DEL", refresh_token_key)

    -- Update statistics
    redis.call("HINCRBY", refresh_token_stats_key, "active_refresh_tokens", -1)

    return true
end

-- Function to revoke all refresh tokens for a user
local function revoke_all_user_refresh_tokens(user_id)
    local user_refresh_tokens_key = user_refresh_tokens_prefix .. user_id
    local refresh_token_ids = redis.call("SMEMBERS", user_refresh_tokens_key)
    local revoked_count = 0

    for i, refresh_token_id in ipairs(refresh_token_ids) do
        local refresh_token_key = refresh_token_prefix .. refresh_token_id

        -- Remove from cleanup set
        redis.call("ZREM", refresh_token_cleanup_key, refresh_token_id)

        -- Delete the refresh token
        redis.call("DEL", refresh_token_key)
        revoked_count = revoked_count + 1
    end

    -- Clear user's refresh tokens set
    redis.call("DEL", user_refresh_tokens_key)

    -- Update statistics
    redis.call("HINCRBY", refresh_token_stats_key, "active_refresh_tokens", -revoked_count)

    return revoked_count
end

-- Function to get refresh token statistics
local function get_refresh_token_stats()
    local stats = redis.call("HGETALL", refresh_token_stats_key)
    local result = {}

    for i = 1, #stats, 2 do
        result[stats[i]] = stats[i + 1]
    end

    return result
end

-- Initialize refresh token statistics if they don't exist
if redis.call("EXISTS", refresh_token_stats_key) == 0 then
    redis.call("HSET", refresh_token_stats_key,
        "total_refresh_tokens", 0,
        "active_refresh_tokens", 0,
        "expired_refresh_tokens", 0,
        "revoked_refresh_tokens", 0
    )
end

-- Export functions for use in other scripts
redis.call("SET", "refresh_token_functions_loaded", "true")

return {ok = "Refresh token management initialized successfully"}
