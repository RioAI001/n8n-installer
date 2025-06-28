#!/bin/bash

# Start the dashboard API server for one-click service functionality

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
API_SCRIPT="$SCRIPT_DIR/dashboard-api.js"
PID_FILE="$PROJECT_ROOT/.dashboard-api.pid"

# Function to check if the API server is running
is_api_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Running
        else
            rm -f "$PID_FILE"  # Remove stale PID file
            return 1  # Not running
        fi
    else
        return 1  # Not running
    fi
}

# Function to start the API server
start_api() {
    echo "🚀 Starting dashboard API server..."
    
    # Check if Node.js is available
    if ! command -v node > /dev/null 2>&1; then
        echo "❌ Node.js is not installed. Installing Node.js..."
        # Try to install Node.js
        if command -v apt-get > /dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y nodejs
        elif command -v yum > /dev/null 2>&1; then
            sudo yum install -y nodejs npm
        else
            echo "❌ Unable to install Node.js automatically. Please install Node.js manually."
            return 1
        fi
    fi
    
    # Start the API server in the background
    cd "$PROJECT_ROOT"
    nohup node "$API_SCRIPT" > "$PROJECT_ROOT/dashboard-api.log" 2>&1 &
    local api_pid=$!
    
    # Save the PID
    echo "$api_pid" > "$PID_FILE"
    
    # Give it a moment to start
    sleep 2
    
    # Check if it's actually running
    if ps -p "$api_pid" > /dev/null 2>&1; then
        echo "✅ Dashboard API server started successfully (PID: $api_pid)"
        echo "📊 API available at: http://127.0.0.1:3998"
        echo "📜 Logs: $PROJECT_ROOT/dashboard-api.log"
        return 0
    else
        echo "❌ Failed to start dashboard API server"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Function to stop the API server
stop_api() {
    if is_api_running; then
        local pid=$(cat "$PID_FILE")
        echo "🛑 Stopping dashboard API server (PID: $pid)..."
        kill "$pid"
        
        # Wait for it to stop
        for i in {1..10}; do
            if ! ps -p "$pid" > /dev/null 2>&1; then
                break
            fi
            sleep 0.5
        done
        
        # Force kill if it's still running
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "🔨 Force stopping API server..."
            kill -9 "$pid"
        fi
        
        rm -f "$PID_FILE"
        echo "✅ Dashboard API server stopped"
    else
        echo "ℹ️  Dashboard API server is not running"
    fi
}

# Function to show API status
status_api() {
    if is_api_running; then
        local pid=$(cat "$PID_FILE")
        echo "✅ Dashboard API server is running (PID: $pid)"
        echo "📊 API available at: http://127.0.0.1:3998"
        
        # Try to query the health endpoint
        if command -v curl > /dev/null 2>&1; then
            echo "🔍 Health check:"
            curl -s http://127.0.0.1:3998/health | head -1
        fi
    else
        echo "❌ Dashboard API server is not running"
    fi
}

# Main execution
case "${1:-start}" in
    "start")
        if is_api_running; then
            echo "ℹ️  Dashboard API server is already running"
            status_api
        else
            start_api
        fi
        ;;
    "stop")
        stop_api
        ;;
    "restart")
        stop_api
        sleep 1
        start_api
        ;;
    "status")
        status_api
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the dashboard API server"
        echo "  stop    - Stop the dashboard API server"
        echo "  restart - Restart the dashboard API server"
        echo "  status  - Show API server status"
        ;;
esac
