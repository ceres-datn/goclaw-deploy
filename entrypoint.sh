#!/bin/sh
set -e

# Graceful shutdown: kill both processes
shutdown() {
    kill "$GOCLAW_PID" 2>/dev/null
    kill "$NGINX_PID" 2>/dev/null
    wait "$GOCLAW_PID" "$NGINX_PID" 2>/dev/null
    exit 0
}

case "${1:-serve}" in
    serve)
        # Managed mode: auto-upgrade before starting
        if [ "$GOCLAW_MODE" = "managed" ] && [ -n "$GOCLAW_POSTGRES_DSN" ]; then
            echo "Managed mode: running upgrade..."
            /app/goclaw upgrade || echo "Upgrade warning (may already be up-to-date)"
        fi

        # Start goclaw in background
        /app/goclaw &
        GOCLAW_PID=$!

        # Start nginx in foreground (as background job for wait)
        nginx -g 'daemon off;' &
        NGINX_PID=$!

        trap shutdown SIGTERM SIGINT

        # Wait for either process to exit
        wait
        ;;
    *)
        # Pass through any other command to goclaw
        exec /app/goclaw "$@"
        ;;
esac
