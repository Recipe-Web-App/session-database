-- Initialize Recipe Scraper Queue Database (DB 2)
-- Job queue for recipe scraper service

local config_key = "scraper_queue_config"
local stats_key = "scraper_queue_stats"
local patterns_key = "scraper_queue_key_patterns"

-- Initialize configuration
redis.call("HSET", config_key,
    "database", 2,
    "service", "recipe-scraper",
    "purpose", "job-queue",
    "max_retries", 3,
    "retry_delay", 60,             -- 1 minute
    "job_timeout", 300,            -- 5 minutes
    "max_queue_size", 10000,
    "initialized_at", redis.call("TIME")[1]
)

-- Initialize statistics
redis.call("HSET", stats_key,
    "total_jobs", 0,
    "pending_jobs", 0,
    "processing_jobs", 0,
    "completed_jobs", 0,
    "failed_jobs", 0,
    "retried_jobs", 0,
    "dead_letter_jobs", 0,
    "last_processed", 0
)

-- Document key patterns
redis.call("HSET", patterns_key,
    "pending", "scraper:queue:pending",
    "processing", "scraper:queue:processing",
    "completed", "scraper:queue:completed",
    "failed", "scraper:queue:failed",
    "dead_letter", "scraper:queue:dead_letter",
    "job_data", "scraper:queue:job:*"
)

return {ok = "Recipe scraper queue initialized in DB 2"}
