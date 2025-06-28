#!/bin/bash

# Auto-start service script for n8n-installer
# Handles one-click service launch from the dashboard

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Service to profile mapping
declare -A SERVICE_PROFILES=(
    ["n8n"]="n8n"
    ["flowise"]="flowise"
    ["open-webui"]="open-webui"
    ["grafana"]="monitoring"
    ["prometheus"]="monitoring"
    ["supabase"]="supabase"
    ["langfuse"]="langfuse"
    ["qdrant"]="qdrant"
    ["weaviate"]="weaviate"
    ["neo4j"]="neo4j"
    ["searxng"]="searxng"
    ["crawl4ai"]="crawl4ai"
    ["letta"]="letta"
    ["ollama"]="cpu"
)

# Service to container name mapping
declare -A SERVICE_CONTAINERS=(
    ["n8n"]="n8n"
    ["flowise"]="flowise"
    ["open-webui"]="open-webui"
    ["grafana"]="grafana"
    ["prometheus"]="prometheus"
    ["supabase"]="kong"
    ["langfuse"]="langfuse-web"
    ["qdrant"]="qdrant"
    ["weaviate"]="weaviate"
    ["neo4j"]="neo4j"
    ["searxng"]="searxng"
    ["crawl4ai"]="crawl4ai"
    ["letta"]="letta-server"
)

# Service health check endpoints
declare -A SERVICE_HEALTH_CHECKS=(
    ["n8n"]="http://localhost:5678/healthz"
    ["flowise"]="http://localhost:3001/api/v1/ping"
    ["open-webui"]="http://localhost:8080"
    ["grafana"]="http://localhost:3000/api/health"
    ["prometheus"]="http://localhost:9090/-/healthy"
    ["supabase"]="http://localhost:8001/health"
    ["langfuse"]="http://localhost:3030/api/public/health"
    ["qdrant"]="http://localhost:6333/health"
    ["weaviate"]="http://localhost:8088/v1/.well-known/ready"
    ["neo4j"]="http://localhost:7474"
    ["searxng"]="http://localhost:8081"
)

# Function to check if service is running
is_service_running() {
    local service="$1"
    local container="${SERVICE_CONTAINERS[$service]}"
    
    if [[ -z "$container" ]]; then
        echo "false"
        return
    fi
    
    cd "$PROJECT_ROOT"
    if docker-compose ps "$container" 2>/dev/null | grep -q "Up"; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to check service health
check_service_health() {
    local service="$1"
    local health_url="${SERVICE_HEALTH_CHECKS[$service]}"
    
    if [[ -z "$health_url" ]]; then
        # If no health check URL, just check if container is running
        return 0
    fi
    
    # Simple curl health check with timeout
    if curl -sf --max-time 5 "$health_url" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to wait for service to be healthy
wait_for_service_ready() {
    local service="$1"
    local max_attempts=30
    local attempt=0
    
    echo -e "${YELLOW}⏳ Waiting for $service to be ready...${NC}"
    
    while [[ $attempt -lt $max_attempts ]]; do
        if check_service_health "$service"; then
            echo -e "${GREEN}✅ $service is ready!${NC}"
            return 0
        fi
        
        echo -e "${BLUE}   Attempt $((attempt + 1))/$max_attempts...${NC}"
        sleep 2
        ((attempt++))
    done
    
    echo -e "${YELLOW}⚠️  $service may still be starting up...${NC}"
    return 0  # Don't fail, just proceed
}

# Function to start service profile
start_service_profile() {
    local service="$1"
    local profile="${SERVICE_PROFILES[$service]}"
    
    if [[ -z "$profile" ]]; then
        echo -e "${RED}❌ Unknown service: $service${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🚀 Starting $service service...${NC}"
    cd "$PROJECT_ROOT"
    
    # Start the profile
    docker-compose --profile "$profile" up -d
    
    # Wait for service to be ready
    wait_for_service_ready "$service"
}

# Function to auto-start and open service
auto_start_service() {
    local service="$1"
    local url="$2"
    
    if [[ -z "$service" || -z "$url" ]]; then
        echo -e "${RED}❌ Service and URL required${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🎯 Processing request for $service...${NC}"
    
    # Check if service is already running
    if [[ "$(is_service_running "$service")" == "true" ]]; then
        echo -e "${GREEN}✅ $service is already running${NC}"
        # Still check health in case it's starting up
        if ! check_service_health "$service"; then
            echo -e "${YELLOW}🔄 Service is starting, waiting...${NC}"
            wait_for_service_ready "$service"
        fi
    else
        echo -e "${YELLOW}🛠️  $service is not running, starting now...${NC}"
        start_service_profile "$service"
    fi
    
    # Open the service URL
    echo -e "${GREEN}🌐 Opening $service at $url${NC}"
    
    # For Windows Subsystem for Linux, try multiple browser opening methods
    if command -v powershell.exe >/dev/null 2>&1; then
        # WSL environment
        powershell.exe -Command "Start-Process '$url'"
    elif command -v cmd.exe >/dev/null 2>&1; then
        # WSL environment alternative
        cmd.exe /c start "$url"
    elif command -v xdg-open >/dev/null 2>&1; then
        # Linux desktop environment
        xdg-open "$url"
    elif command -v open >/dev/null 2>&1; then
        # macOS
        open "$url"
    else
        echo -e "${YELLOW}⚠️  Could not open browser automatically. Please visit: $url${NC}"
    fi
}

# Main execution
main() {
    case "${1:-}" in
        "start")
            if [[ -z "${2:-}" || -z "${3:-}" ]]; then
                echo -e "${RED}❌ Usage: $0 start <service> <url>${NC}"
                echo "Example: $0 start n8n https://n8n.local"
                exit 1
            fi
            auto_start_service "$2" "$3"
            ;;
        "check")
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}❌ Usage: $0 check <service>${NC}"
                exit 1
            fi
            service="$2"
            if [[ "$(is_service_running "$service")" == "true" ]]; then
                echo -e "${GREEN}✅ $service is running${NC}"
                if check_service_health "$service"; then
                    echo -e "${GREEN}✅ $service is healthy${NC}"
                else
                    echo -e "${YELLOW}⚠️  $service is starting up${NC}"
                fi
            else
                echo -e "${RED}❌ $service is not running${NC}"
            fi
            ;;
        *)
            echo -e "${BLUE}🚀 Auto-start Service Script${NC}"
            echo ""
            echo "Usage: $0 {start|check}"
            echo ""
            echo "Commands:"
            echo "  start <service> <url>  - Auto-start service and open URL"
            echo "  check <service>        - Check service status"
            echo ""
            echo "Available services:"
            for service in "${!SERVICE_PROFILES[@]}"; do
                echo "  $service"
            done | sort
            ;;
    esac
}

# Run main function
main "$@"
