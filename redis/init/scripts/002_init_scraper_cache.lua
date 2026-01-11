-- Initialize Recipe Scraper Cache Database (DB 1)
-- Response/resource cache for recipe scraper service

local config_key = "scraper_cache_config"
local stats_key = "scraper_cache_stats"
local patterns_key = "scraper_cache_key_patterns"

-- Initialize configuration
redis.call("HSET", config_key,
    "database", 1,
    "service", "recipe-scraper",
    "purpose", "response-cache",
    "default_ttl", 86400,          -- 24 hours
    "recipe_ttl", 604800,          -- 7 days for recipes
    "search_ttl", 3600,            -- 1 hour for search results
    "max_entries", 10000,
    "initialized_at", redis.call("TIME")[1]
)

-- Initialize statistics
redis.call("HSET", stats_key,
    "total_entries", 0,
    "active_entries", 0,
    "cache_hits", 0,
    "cache_misses", 0,
    "evicted_entries", 0,
    "expired_entries", 0,
    "bytes_stored", 0,
    "last_cleanup", 0
)

-- Document key patterns
redis.call("HSET", patterns_key,
    "recipe", "scraper:cache:recipe:*",
    "search", "scraper:cache:search:*",
    "ingredient", "scraper:cache:ingredient:*",
    "nutrition", "scraper:cache:nutrition:*"
)

return {ok = "Recipe scraper cache initialized in DB 1"}
