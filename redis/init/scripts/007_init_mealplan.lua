-- Initialize Meal Plan Management Database (DB 6)
-- Meal plan cache for meal planning service

local config_key = "mealplan_config"
local stats_key = "mealplan_stats"
local patterns_key = "mealplan_key_patterns"

-- Initialize configuration
redis.call("HSET", config_key,
    "database", 6,
    "service", "meal-plan-management",
    "purpose", "mealplan-cache",
    "default_ttl", 86400,          -- 24 hours
    "plan_ttl", 604800,            -- 7 days
    "shopping_list_ttl", 86400,    -- 24 hours
    "max_plans_cached", 10000,
    "initialized_at", redis.call("TIME")[1]
)

-- Initialize statistics
redis.call("HSET", stats_key,
    "total_plans_cached", 0,
    "active_plans", 0,
    "cache_hits", 0,
    "cache_misses", 0,
    "plans_generated", 0,
    "shopping_lists_generated", 0,
    "last_cleanup", 0
)

-- Document key patterns
redis.call("HSET", patterns_key,
    "plan", "mealplan:plan:*",
    "weekly", "mealplan:weekly:*",
    "shopping_list", "mealplan:shopping:*",
    "suggestions", "mealplan:suggest:*",
    "user_history", "mealplan:history:*"
)

return {ok = "Meal plan management cache initialized in DB 6"}
