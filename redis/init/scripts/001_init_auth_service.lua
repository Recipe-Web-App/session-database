-- Initialize OAuth2 Authentication Service Redis structures
-- This script sets up the basic Redis structure for OAuth2 auth service

-- Auth service key prefixes
local client_prefix = "auth:client:"
local code_prefix = "auth:code:"
local access_token_prefix = "auth:access_token:"
local refresh_token_prefix = "auth:refresh_token:"
local session_prefix = "auth:session:"
local blacklist_prefix = "auth:blacklist:"
local rate_limit_prefix = "auth:rate_limit:"

-- Configuration and statistics keys
local auth_config_key = "auth_config"
local auth_stats_key = "auth_stats"
local token_cleanup_key = "auth_token_cleanup"

-- Initialize auth configuration
redis.call("HSET", auth_config_key,
    "authorization_code_expiry", 600,     -- 10 minutes
    "access_token_expiry", 900,           -- 15 minutes
    "refresh_token_expiry", 604800,       -- 7 days (168 hours)
    "session_timeout", 3600,              -- 1 hour
    "rate_limit_window", 60,              -- 1 minute
    "rate_limit_requests", 100,           -- requests per window
    "max_sessions_per_user", 5,
    "token_cleanup_interval", 300,        -- 5 minutes
    "blacklist_retention", 86400          -- 24 hours
)

-- Initialize auth statistics
redis.call("HSET", auth_stats_key,
    "total_clients", 0,
    "active_clients", 0,
    "total_authorization_codes", 0,
    "active_authorization_codes", 0,
    "expired_authorization_codes", 0,
    "total_access_tokens", 0,
    "active_access_tokens", 0,
    "expired_access_tokens", 0,
    "revoked_access_tokens", 0,
    "total_refresh_tokens", 0,
    "active_refresh_tokens", 0,
    "expired_refresh_tokens", 0,
    "revoked_refresh_tokens", 0,
    "total_sessions", 0,
    "active_sessions", 0,
    "expired_sessions", 0,
    "blacklisted_tokens", 0,
    "rate_limited_requests", 0,
    "last_cleanup", 0
)

-- Initialize token cleanup sorted set if it doesn't exist
if redis.call("EXISTS", token_cleanup_key) == 0 then
    redis.call("DEL", token_cleanup_key)
end

-- Set up default rate limiting structure
redis.call("HSET", "auth:rate_limit_config",
    "default_requests_per_minute", 100,
    "client_requests_per_minute", 1000,
    "ip_requests_per_minute", 50,
    "token_requests_per_minute", 200,
    "introspection_requests_per_minute", 500
)

return {ok = "Auth service initialized successfully"}
