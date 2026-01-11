-- Initialize Notification Service Database (DB 5)
-- Notification queue and state management

local config_key = "notification_config"
local stats_key = "notification_stats"
local patterns_key = "notification_key_patterns"

-- Initialize configuration
redis.call("HSET", config_key,
    "database", 5,
    "service", "notification-service",
    "purpose", "notification-queue",
    "default_ttl", 86400,          -- 24 hours
    "urgent_ttl", 3600,            -- 1 hour for urgent
    "batch_size", 100,
    "retry_limit", 3,
    "initialized_at", redis.call("TIME")[1]
)

-- Initialize statistics
redis.call("HSET", stats_key,
    "total_notifications", 0,
    "pending_notifications", 0,
    "sent_notifications", 0,
    "failed_notifications", 0,
    "email_sent", 0,
    "push_sent", 0,
    "sms_sent", 0,
    "last_processed", 0
)

-- Document key patterns
redis.call("HSET", patterns_key,
    "pending", "notification:pending",
    "processing", "notification:processing",
    "sent", "notification:sent:*",
    "failed", "notification:failed:*",
    "user_prefs", "notification:prefs:*",
    "templates", "notification:template:*"
)

return {ok = "Notification service initialized in DB 5"}
