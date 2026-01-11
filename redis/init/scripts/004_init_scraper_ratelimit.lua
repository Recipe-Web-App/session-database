-- Initialize Recipe Scraper Rate Limit Database (DB 3)
-- Rate limiting for recipe scraper service

local config_key = "scraper_ratelimit_config"
local stats_key = "scraper_ratelimit_stats"
local patterns_key = "scraper_ratelimit_key_patterns"

-- Initialize configuration
redis.call("HSET", config_key,
    "database", 3,
    "service", "recipe-scraper",
    "purpose", "rate-limiting",
    "window_seconds", 60,          -- 1 minute window
    "default_limit", 100,          -- requests per window
    "per_domain_limit", 30,        -- per external domain
    "burst_limit", 10,             -- burst allowance
    "initialized_at", redis.call("TIME")[1]
)

-- Initialize statistics
redis.call("HSET", stats_key,
    "total_requests", 0,
    "allowed_requests", 0,
    "blocked_requests", 0,
    "domains_tracked", 0,
    "active_windows", 0,
    "last_reset", 0
)

-- Document key patterns
redis.call("HSET", patterns_key,
    "global", "scraper:ratelimit:global",
    "domain", "scraper:ratelimit:domain:*",
    "ip", "scraper:ratelimit:ip:*",
    "user", "scraper:ratelimit:user:*"
)

return {ok = "Recipe scraper rate limiting initialized in DB 3"}
