FROM redis:7.2-alpine

# Install additional tools
RUN apk add --no-cache \
    bash \
    curl \
    && rm -rf /var/cache/apk/*

# Copy Redis configuration
COPY redis/init/config/redis.conf /usr/local/etc/redis/redis.conf

# Create directories for data and logs
RUN mkdir -p /data /logs && chown -R redis:redis /data /logs

# Expose Redis port
EXPOSE 6379

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD redis-cli ping || exit 1

# Start Redis with custom config
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
