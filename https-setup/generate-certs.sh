#!/bin/bash

# Certificate Generation Script for Local Development
# This script generates mkcert certificates for all local domains

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$SCRIPT_DIR/certs"

echo -e "${BLUE}🔐 Generating certificates for local development${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if mkcert is installed
check_mkcert() {
    if ! command_exists mkcert; then
        echo -e "${RED}❌ mkcert is not installed. Please run setup-https.sh first.${NC}"
        exit 1
    fi
}

# Generate certificates for all services
generate_certificates() {
    echo -e "${YELLOW}📜 Generating certificates for local domains...${NC}"
    
    # Ensure certs directory exists
    mkdir -p "$CERTS_DIR"
    cd "$CERTS_DIR"
    
    # Remove any existing certificates
    rm -f *.pem *.key
    
    # List of domains for certificates
    domains=(
        "n8n.local"
        "n8n-dashboard.local"
        "grafana.local"
        "supabase.local"
        "langfuse.local"
        "flowise.local"
        "webui.local"
        "searxng.local"
        "weaviate.local"
        "neo4j.local"
        "prometheus.local"
        "letta.local"
        "qdrant.local"
    )
    
    echo -e "${BLUE}🏗️  Generating certificates for domains:${NC}"
    for domain in "${domains[@]}"; do
        echo "  - $domain"
    done
    
    # Generate a single certificate for all domains
    mkcert "${domains[@]}"
    
    # Find the generated files and rename them to standard names
    cert_file=$(ls *.pem | grep -v key | head -1)
    key_file=$(ls *-key.pem | head -1)
    
    if [[ -n "$cert_file" && -n "$key_file" ]]; then
        mv "$cert_file" "local-domains.pem"
        mv "$key_file" "local-domains-key.pem"
        echo -e "${GREEN}✅ Certificates generated successfully:${NC}"
        echo "  - Certificate: local-domains.pem"
        echo "  - Private Key: local-domains-key.pem"
    else
        echo -e "${RED}❌ Failed to generate certificates${NC}"
        exit 1
    fi
    
    # Set proper permissions
    chmod 644 local-domains.pem
    chmod 600 local-domains-key.pem
    
    echo -e "${GREEN}📁 Certificates stored in: $CERTS_DIR${NC}"
    ls -la "$CERTS_DIR"
}

# Update .env file with local domains
update_env_file() {
    echo -e "${YELLOW}⚙️  Creating .env.https template...${NC}"
    
    local env_https="$PROJECT_ROOT/.env.https"
    
    # Create a copy of the current .env with .local domains
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        cp "$PROJECT_ROOT/.env" "$env_https"
        
        # Replace .mypc.com domains with .local domains
        sed -i 's/\.mypc\.com/.local/g' "$env_https"
        
        echo -e "${GREEN}✅ Created .env.https template${NC}"
        echo -e "${YELLOW}📋 To use HTTPS, replace your .env file with .env.https:${NC}"
        echo "  cp .env.https .env"
    else
        echo -e "${YELLOW}⚠️  .env file not found, skipping .env.https creation${NC}"
    fi
}

# Create Windows hosts file entries
create_hosts_entries() {
    echo -e "${YELLOW}📝 Creating Windows hosts file entries...${NC}"
    
    local hosts_file="$SCRIPT_DIR/windows-hosts-entries.txt"
    
    cat > "$hosts_file" << 'EOF'
# Add these entries to your Windows hosts file:
# C:\Windows\System32\drivers\etc\hosts
#
# You can copy and paste the lines below (without the # comments)

127.0.0.1    n8n.local
127.0.0.1    n8n-dashboard.local
127.0.0.1    grafana.local
127.0.0.1    supabase.local
127.0.0.1    langfuse.local
127.0.0.1    flowise.local
127.0.0.1    webui.local
127.0.0.1    searxng.local
127.0.0.1    weaviate.local
127.0.0.1    neo4j.local
127.0.0.1    prometheus.local
127.0.0.1    letta.local
127.0.0.1    qdrant.local

# End of n8n-installer HTTPS entries
EOF
    
    echo -e "${GREEN}✅ Created Windows hosts file entries in: $hosts_file${NC}"
}

# Main execution
main() {
    case "${1:-}" in
        --update-caddyfile)
            echo -e "${BLUE}📝 HTTPS Caddyfile template is available at:${NC}"
            echo "$SCRIPT_DIR/templates/Caddyfile.https"
            echo ""
            echo -e "${YELLOW}To use HTTPS:${NC}"
            echo "1. Backup your current Caddyfile:"
            echo "   cp Caddyfile Caddyfile.backup"
            echo ""
            echo "2. Replace with HTTPS version:"
            echo "   cp https-setup/templates/Caddyfile.https Caddyfile"
            ;;
        *)
            check_mkcert
            generate_certificates
            update_env_file
            create_hosts_entries
            
            echo ""
            echo -e "${GREEN}🎉 Certificate generation completed!${NC}"
            echo ""
            echo -e "${YELLOW}📋 Next steps:${NC}"
            echo "1. Add the entries from 'windows-hosts-entries.txt' to your Windows hosts file"
            echo "2. Replace your .env with the HTTPS version:"
            echo "   cp .env.https .env"
            echo "3. Replace your Caddyfile with the HTTPS version:"
            echo "   cp https-setup/templates/Caddyfile.https Caddyfile"
            echo "4. Restart your services:"
            echo "   docker-compose down && docker-compose up -d"
            ;;
    esac
}

# Run main function
main "$@"
