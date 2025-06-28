#!/bin/bash

# HTTPS Setup Script for Local Development
# This script installs mkcert and generates certificates for local domains

set -e

echo "🔐 Setting up HTTPS for local development..."

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

echo -e "${BLUE}📂 Working in: $SCRIPT_DIR${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install mkcert if not already installed
install_mkcert() {
    echo -e "${YELLOW}🔍 Checking for mkcert...${NC}"
    
    if command_exists mkcert; then
        echo -e "${GREEN}✅ mkcert is already installed${NC}"
        mkcert -version
        return 0
    fi
    
    echo -e "${YELLOW}📦 Installing mkcert...${NC}"
    
    # Detect OS and install accordingly
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check if we're in WSL
        if grep -qi microsoft /proc/version; then
            echo -e "${BLUE}🐧 Detected WSL environment${NC}"
        fi
        
        # Install mkcert for Linux
        if command_exists apt-get; then
            sudo apt update
            sudo apt install -y libnss3-tools
            
            # Download and install mkcert
            curl -s https://api.github.com/repos/FiloSottile/mkcert/releases/latest \
            | grep browser_download_url \
            | grep linux-amd64 \
            | cut -d '"' -f 4 \
            | wget -qi -
            
            chmod +x mkcert-v*-linux-amd64
            sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
            
        elif command_exists yum; then
            sudo yum install -y nss-tools
            # Similar download process for RHEL/CentOS
        fi
        
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command_exists brew; then
            brew install mkcert
        else
            echo -e "${RED}❌ Homebrew not found. Please install mkcert manually.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Unsupported OS. Please install mkcert manually.${NC}"
        exit 1
    fi
    
    if command_exists mkcert; then
        echo -e "${GREEN}✅ mkcert installed successfully${NC}"
        mkcert -version
    else
        echo -e "${RED}❌ Failed to install mkcert${NC}"
        exit 1
    fi
}

# Install the local CA
setup_ca() {
    echo -e "${YELLOW}🔑 Setting up local Certificate Authority...${NC}"
    mkcert -install
    echo -e "${GREEN}✅ Local CA installed${NC}"
}

# Generate certificates for all services
generate_certificates() {
    echo -e "${YELLOW}📜 Generating certificates...${NC}"
    
    # Ensure certs directory exists
    mkdir -p "$CERTS_DIR"
    cd "$CERTS_DIR"
    
    # List of domains for certificates
    domains=(
        "n8n.local"
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
    
    # Rename the generated files to standard names
    mv "_wildcard.local+11.pem" "local-domains.pem" 2>/dev/null || true
    mv "_wildcard.local+11-key.pem" "local-domains-key.pem" 2>/dev/null || true
    
    # If the above doesn't work, find the generated files
    if [[ ! -f "local-domains.pem" ]]; then
        cert_file=$(ls *.pem | grep -v key | head -1)
        key_file=$(ls *-key.pem | head -1)
        if [[ -n "$cert_file" ]]; then
            mv "$cert_file" "local-domains.pem"
        fi
        if [[ -n "$key_file" ]]; then
            mv "$key_file" "local-domains-key.pem"
        fi
    fi
    
    echo -e "${GREEN}✅ Certificates generated in: $CERTS_DIR${NC}"
    ls -la "$CERTS_DIR"
}

# Update the Caddyfile
update_caddyfile() {
    echo -e "${YELLOW}⚙️  Updating Caddyfile for HTTPS...${NC}"
    
    # Create the HTTPS Caddyfile template
    "$SCRIPT_DIR/generate-certs.sh" --update-caddyfile
    
    echo -e "${GREEN}✅ Caddyfile template created${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting HTTPS setup for n8n-installer project${NC}"
    
    install_mkcert
    setup_ca
    generate_certificates
    
    echo ""
    echo -e "${GREEN}🎉 HTTPS setup completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Next steps:${NC}"
    echo "1. Add the following entries to your Windows hosts file:"
    echo "   C:\\Windows\\System32\\drivers\\etc\\hosts"
    echo ""
    echo "   127.0.0.1    n8n.local"
    echo "   127.0.0.1    grafana.local"
    echo "   127.0.0.1    supabase.local"
    echo "   127.0.0.1    langfuse.local"
    echo "   127.0.0.1    flowise.local"
    echo "   127.0.0.1    webui.local"
    echo "   127.0.0.1    searxng.local"
    echo "   127.0.0.1    weaviate.local"
    echo "   127.0.0.1    neo4j.local"
    echo "   127.0.0.1    prometheus.local"
    echo "   127.0.0.1    letta.local"
    echo "   127.0.0.1    qdrant.local"
    echo ""
    echo "2. Update your .env file to use .local domains"
    echo "3. Use the HTTPS Caddyfile template"
    echo "4. Restart your Docker services"
    echo ""
    echo -e "${BLUE}📖 See README.md for detailed instructions${NC}"
}

# Run main function
main "$@"
