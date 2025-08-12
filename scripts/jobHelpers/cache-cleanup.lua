-- Simplified cache cleanup script for service cache database (DB 1)
-- Basic TTL-based cleanup without complex eviction logic

local batch_size = tonumber(ARGV[1]) or 100
local start_time = redis.call("TIME")[1] * 1000 + math.floor(redis.call("TIME")[2] / 1000)

-- Switch to cache database (DB 1)
redis.call("SELECT", 1)

-- Simple cleanup: let Redis handle TTL expiration automatically
-- Just count current cache entries and update basic stats

local function update_cache_statistics()
    -- Count only actual cache data keys (exclude infrastructure keys)
    local cache_data_keys = redis.call("KEYS", "cache:resource:*")
    local active_count = #cache_data_keys

    -- Update basic cache stats
    redis.call("HSET", "cache_stats",
        "active_cache_entries", active_count,
        "total_cache_entries", active_count,
        "last_cleanup", start_time
    )

    return active_count
end

-- Main cleanup execution (Redis handles TTL automatically)
local active_entries = update_cache_statistics()

-- Update cleanup metrics
redis.call("HINCRBY", "cache_cleanup_metrics", "total_cleanups_performed", 1)

local end_time = redis.call("TIME")[1] * 1000 + math.floor(redis.call("TIME")[2] / 1000)
local duration = end_time - start_time

redis.call("HSET", "cache_cleanup_metrics", "last_cleanup_duration_ms", duration)

-- Update cleanup config
redis.call("HSET", "cache_cleanup_config", "last_cleanup_timestamp", start_time)

return {
    active_entries = active_entries,
    duration_ms = duration,
    database = 1,
    message = "TTL-based cleanup completed (Redis handles expiration automatically)"
}
