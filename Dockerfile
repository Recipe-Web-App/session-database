FROM redis:8.4-alpine

# Install additional tools
RUN apk add --no-cache \
    bash \
    curl \
    gettext \
    && rm -rf /var/cache/apk/*

# Copy Redis configuration
COPY redis/init/config/redis.conf /usr/local/etc/redis/redis.conf.template

# Copy Lua scripts for session management
COPY redis/init/scripts/*.lua /usr/local/etc/redis/scripts/

# Create directories for data and logs
RUN mkdir -p /data /logs && chown -R redis:redis /data /logs

# Copy startup script
COPY redis/init/scripts/start-redis.sh /usr/local/bin/start-redis.sh
COPY redis/init/scripts/init-lua-scripts.sh /usr/local/bin/init-lua-scripts.sh
RUN chmod +x /usr/local/bin/start-redis.sh /usr/local/bin/init-lua-scripts.sh

# Expose Redis port
EXPOSE 6379

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD redis-cli ping || exit 1

# Start Redis with custom config
CMD ["/usr/local/bin/start-redis.sh"]
