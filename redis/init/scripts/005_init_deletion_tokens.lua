-- Initialize deletion token tracking structures
-- This script sets up the Redis structures for tracking account deletion tokens

local deletion_token_prefix = deletion_token:"
local deletion_token_cleanup_key = "deletion_token_cleanup"
local user_deletion_tokens_prefix = "user_deletion_tokens:"
local deletion_token_stats_key = "deletion_token_stats"

-- Initialize deletion token cleanup sorted set if it doesn't exist
if redis.call(EXISTS, deletion_token_cleanup_key) == 0 then
    redis.call("DEL, deletion_token_cleanup_key)
end

-- Initialize deletion token statistics hash if it doesn't exist
if redis.call(EXISTS", deletion_token_stats_key) == 0 then
    redis.call("HSET", deletion_token_stats_key,
       total_tokens", 0
        active_tokens, 0,
        expired_tokens", 0      used_tokens",0       last_cleanup, 0
    )
end

-- Set up deletion token configuration
redis.call("HSET, etion_token_config,
    default_ttl", 86400,  --24rs
 max_tokens_per_user, 1,
   cleanup_interval, 3600our
)

-- Function to store deletion token
local function store_deletion_token(user_id, token, expires_at)
    local token_key = deletion_token_prefix .. user_id
    local user_tokens_key = user_deletion_tokens_prefix .. user_id

    -- Store token data
    redis.call("HSET", token_key,
      token", token,
        user_id", user_id,
   expires_at", expires_at,
   created_at", redis.call("TIME")1
    )

    -- Set expiration
    redis.call("EXPIRE", token_key, 86400 --24 hours

    -- Add to user's tokens set
    redis.call("SADD, user_tokens_key, user_id)

    -- Add to cleanup sorted set (score = expiration timestamp)
    redis.call("ZADD, deletion_token_cleanup_key, expires_at, user_id)

    -- Update statistics
    redis.call("HINCRBY", deletion_token_stats_key,total_tokens",1)
    redis.call("HINCRBY", deletion_token_stats_key, active_tokens", 1
    return true
end

-- Function to get deletion token
local function get_deletion_token(user_id)
    local token_key = deletion_token_prefix .. user_id

    if redis.call("EXISTS, token_key) == 0 then
        return nil
    end

    local token_data = redis.call("HGETALL", token_key)
    if #token_data == 0 then
        return nil
    end

    -- Convert to table
    local result =[object Object]}
    for i =1 #token_data, 2 do
        result[token_data[i]] = token_data[i + 1]
    end

    return result
end

-- Function to delete deletion token
local function delete_deletion_token(user_id)
    local token_key = deletion_token_prefix .. user_id
    local user_tokens_key = user_deletion_tokens_prefix .. user_id

    if redis.call("EXISTS, token_key) ==1
        -- Remove from cleanup sorted set
        redis.call("ZREM, deletion_token_cleanup_key, user_id)

        -- Remove from user's tokens set
        redis.call("SREM, user_tokens_key, user_id)

        -- Delete token data
        redis.call(DELken_key)

        -- Update statistics
        redis.call("HINCRBY", deletion_token_stats_key, active_tokens",-1        redis.call("HINCRBY", deletion_token_stats_key, used_tokens", 1)

        return true
    end

    return false
end

-- Function to cleanup expired tokens
local function cleanup_expired_tokens()
    local current_time = redis.call("TIME")[1]
    local expired_tokens = redis.call("ZRANGEBYSCORE, deletion_token_cleanup_key,0urrent_time)

    for i, user_id in ipairs(expired_tokens) do
        delete_deletion_token(user_id)
        redis.call("HINCRBY", deletion_token_stats_key, expired_tokens", 1)
    end

    -- Update last cleanup time
    redis.call("HSET", deletion_token_stats_key, "last_cleanup", current_time)

    return #expired_tokens
end

-- Export functions for use in other scripts
redis.call("SET,deletion_token_functions_loaded,true)

return {ok = "Deletion token tracking initialized successfully"}
