#!/bin/bash

# Service Manager Script for n8n-installer
# Provides intelligent service management and status checking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Function to check if service is running
check_service() {
    local service_name="$1"
    if docker-compose ps "$service_name" 2>/dev/null | grep -q "Up"; then
        echo "running"
    else
        echo "stopped"
    fi
}

# Function to start a service profile
start_profile() {
    local profile="$1"
    echo -e "${BLUE}🚀 Starting profile: $profile${NC}"
    cd "$PROJECT_ROOT"
    docker-compose --profile "$profile" up -d
}

# Function to start all essential services
start_all() {
    echo -e "${BLUE}🚀 Starting all essential services...${NC}"
    cd "$PROJECT_ROOT"
    
    # Start services in order of dependency
    echo -e "${YELLOW}📊 Starting monitoring stack...${NC}"
    docker-compose --profile monitoring up -d
    
    echo -e "${YELLOW}🔄 Starting workflow automation...${NC}"
    docker-compose --profile n8n up -d
    
    echo -e "${YELLOW}🤖 Starting AI interfaces...${NC}"
    docker-compose --profile open-webui up -d
    docker-compose --profile flowise up -d
    
    echo -e "${YELLOW}📚 Starting databases...${NC}"
    docker-compose --profile supabase up -d
    docker-compose --profile neo4j up -d
    docker-compose --profile qdrant up -d
    docker-compose --profile weaviate up -d
    
    echo -e "${YELLOW}📈 Starting analytics...${NC}"
    docker-compose --profile langfuse up -d
    
    echo -e "${YELLOW}🔍 Starting search...${NC}"
    docker-compose --profile searxng up -d
    
    echo -e "${GREEN}✅ All services starting...${NC}"
}

# Function to get service status
get_service_status() {
    local service="$1"
    if docker-compose ps "$service" 2>/dev/null | grep -q "Up"; then
        echo -e "${GREEN}✅ Running${NC}"
    else
        echo -e "${RED}❌ Stopped${NC}"
    fi
}

# Function to show service dashboard
show_status() {
    echo -e "${BLUE}🏠 AI Development Stack Status${NC}"
    echo "=================================="
    
    echo -e "\n${YELLOW}🔄 Workflow Automation:${NC}"
    echo -n "  N8N: "; get_service_status "n8n"
    
    echo -e "\n${YELLOW}🤖 AI Interfaces:${NC}"
    echo -n "  Open WebUI: "; get_service_status "open-webui"
    echo -n "  Flowise: "; get_service_status "flowise"
    
    echo -e "\n${YELLOW}📊 Monitoring:${NC}"
    echo -n "  Grafana: "; get_service_status "grafana"
    echo -n "  Prometheus: "; get_service_status "prometheus"
    
    echo -e "\n${YELLOW}📚 Databases:${NC}"
    echo -n "  Supabase: "; get_service_status "kong"
    echo -n "  Neo4j: "; get_service_status "neo4j"
    echo -n "  Qdrant: "; get_service_status "qdrant"
    echo -n "  Weaviate: "; get_service_status "weaviate"
    
    echo -e "\n${YELLOW}📈 Analytics:${NC}"
    echo -n "  Langfuse: "; get_service_status "langfuse-web"
    
    echo -e "\n${YELLOW}🔍 Search:${NC}"
    echo -n "  SearXNG: "; get_service_status "searxng"
    
    echo -e "\n${YELLOW}🌐 Reverse Proxy:${NC}"
    echo -n "  Caddy: "; get_service_status "caddy"
}

# Function to create service URLs
show_urls() {
    echo -e "${BLUE}🌐 Service URLs (HTTPS)${NC}"
    echo "=================================="
    echo "Dashboard: https://local"
    echo "N8N: https://n8n.local"
    echo "Grafana: https://grafana.local"
    echo "Supabase: https://supabase.local"
    echo "Langfuse: https://langfuse.local"
    echo "Open WebUI: https://webui.local"
    echo "Flowise: https://flowise.local"
    echo "SearXNG: https://searxng.local"
    echo "Weaviate: https://weaviate.local"
    echo "Neo4j: https://neo4j.local"
    echo "Prometheus: https://prometheus.local"
    echo "Qdrant: https://qdrant.local"
    echo "Crawl4AI: https://crawl4ai.local"
    echo "Letta: https://letta.local"
}

# Function to auto-start service and open the app
auto_start_service() {
    local profile="$1"
    local port="$2"

    status=$(check_service "$profile")
    if [[ "$status" == "stopped" ]]; then
        echo -e "${YELLOW}Starting $profile service...${NC}"
        start_profile "$profile"
        # Simple wait for the service to be ready
        sleep 10
    fi
    echo -e "${GREEN}Opening $profile app...${NC}"
    openService "$port"
}

# Main execution
main() {
    case "${1:-}" in
        "start-all")
            start_all
            ;;
        "start-profile")
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}❌ Profile name required${NC}"
                echo "Available profiles: n8n, monitoring, open-webui, flowise, supabase, neo4j, qdrant, weaviate, langfuse, searxng"
                exit 1
            fi
            start_profile "$2"
            ;;
        "status")
            show_status
            ;;
        "urls")
            show_urls
            ;;
        "check")
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}❌ Service name required${NC}"
                exit 1
            fi
            check_service "$2"
            ;;
        *)
            echo -e "${BLUE}🔧 AI Development Stack Service Manager${NC}"
            echo ""
            echo "Usage: $0 {start-all|start-profile|status|urls|check}"
            echo ""
            echo "Commands:"
            echo "  start-all                 - Start all essential services"
            echo "  start-profile <profile>   - Start specific service profile"
            echo "  status                    - Show service status"
            echo "  urls                      - Show service URLs"
            echo "  check <service>           - Check specific service status"
            echo ""
            echo "Available profiles:"
            echo "  n8n, monitoring, open-webui, flowise, supabase"
            echo "  neo4j, qdrant, weaviate, langfuse, searxng"
            ;;
    esac
}

# Run main function
main "$@"
