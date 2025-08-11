-- scripts/jobHelpers/session-cleanup.lua
-- Redis Lua script for session cleanup operations

-- Session cleanup script
local session_cleanup_key = "session_cleanup"
local session_prefix = "session:"
local user_sessions_prefix = "user_sessions:"
local session_stats_key = "session_stats"
local refresh_token_cleanup_key = "refresh_token_cleanup"
local refresh_token_prefix = "refresh_token:"
local user_refresh_tokens_prefix = "user_refresh_tokens:"
local deletion_token_cleanup_key = "deletion_token_cleanup"
local deletion_token_prefix = "deletion_token:"

local current_time = redis.call("TIME")[1]
local batch_size = tonumber(ARGV[1]) or 100
local stats = {
  sessions_cleaned = 0,
  refresh_tokens_cleaned = 0,
  deletion_tokens_cleaned = 0,
  errors = 0
}

-- Function to safely get user_id from JSON data
local function extract_user_id(json_data)
  if not json_data then return nil end
  local user_id = string.match(json_data, '"user_id"%s*:%s*"([^"]*)"')
  if not user_id then
    user_id = string.match(json_data, '"user_id"%s*:%s*([^,}%s]*)')
  end
  return user_id
end

-- Cleanup expired sessions
local expired_sessions = redis.call("ZRANGEBYSCORE",
  session_cleanup_key, 0, current_time, "LIMIT", 0, batch_size)
for i, session_id in ipairs(expired_sessions) do
  local session_key = session_prefix .. session_id
  local session_data = redis.call("GET", session_key)

  if session_data then
    local user_id = extract_user_id(session_data)
    if user_id then
      redis.call("SREM", user_sessions_prefix .. user_id, session_id)
    end
    redis.call("DEL", session_key)
    stats.sessions_cleaned = stats.sessions_cleaned + 1
  end

  redis.call("ZREM", session_cleanup_key, session_id)
end

-- Cleanup expired refresh tokens
local expired_refresh_tokens = redis.call("ZRANGEBYSCORE",
  refresh_token_cleanup_key, 0, current_time, "LIMIT", 0, batch_size)
for i, token_id in ipairs(expired_refresh_tokens) do
  local token_key = refresh_token_prefix .. token_id
  local token_data = redis.call("GET", token_key)

  if token_data then
    local user_id = extract_user_id(token_data)
    if user_id then
      redis.call("SREM", user_refresh_tokens_prefix .. user_id, token_id)
    end
    redis.call("DEL", token_key)
    stats.refresh_tokens_cleaned = stats.refresh_tokens_cleaned + 1
  end

  redis.call("ZREM", refresh_token_cleanup_key, token_id)
end

-- Cleanup expired deletion tokens
local expired_deletion_tokens = redis.call("ZRANGEBYSCORE",
  deletion_token_cleanup_key, 0, current_time, "LIMIT", 0, batch_size)
for i, token_id in ipairs(expired_deletion_tokens) do
  local token_key = deletion_token_prefix .. token_id
  redis.call("DEL", token_key)
  redis.call("ZREM", deletion_token_cleanup_key, token_id)
  stats.deletion_tokens_cleaned = stats.deletion_tokens_cleaned + 1
end

-- Update statistics
if stats.sessions_cleaned > 0 then
  redis.call("HINCRBY", session_stats_key,
    "expired_sessions", stats.sessions_cleaned)
end
if stats.refresh_tokens_cleaned > 0 then
  redis.call("HINCRBY", session_stats_key,
    "expired_refresh_tokens", stats.refresh_tokens_cleaned)
end
if stats.deletion_tokens_cleaned > 0 then
  redis.call("HINCRBY", session_stats_key,
    "expired_deletion_tokens", stats.deletion_tokens_cleaned)
end

redis.call("HSET", session_stats_key, "last_cleanup", current_time)
redis.call("HINCRBY", session_stats_key, "cleanup_runs", 1)

return cjson.encode(stats)
