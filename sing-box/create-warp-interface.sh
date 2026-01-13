#!/bin/sh
# This script generates warp key and creates amnezia configuration on your router
# zapret must be configured and cloudflare networks accessible

set -e

# Configuration via environment variables
NETWORK_TAG="${NETWORK_TAG:-warp}"
OVERWRITE="${OVERWRITE:-false}"
ENDPOINT_HOST="${ENDPOINT_HOST:-engage.cloudflareclient.com}"
ENDPOINT_PORT="${ENDPOINT_PORT:-4500}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if interface already exists
check_interface_exists() {
    local iface_name="$1"
    if uci get "network.${iface_name}" >/dev/null 2>&1; then
        return 0  # exists
    fi
    return 1  # does not exist
}

# Delete existing interface and its peer configuration
delete_interface() {
    local iface_name="$1"
    log_warn "Deleting existing interface: ${iface_name}"
    
    # Find and delete the amneziawg peer section
    local idx=0
    while true; do
        local section_name
        section_name=$(uci -q get "network.@amneziawg_${iface_name}[${idx}]" 2>/dev/null) || break
        uci delete "network.@amneziawg_${iface_name}[0]" 2>/dev/null || true
    done
    
    # Delete the interface itself
    uci delete "network.${iface_name}" 2>/dev/null || true
    
    log_info "Deleted interface ${iface_name}"
}

# Fetch keys from the generator endpoint
fetch_keys() {
    log_info "Fetching keys from warp generator..."
    
    local response
    response=$(curl -s 'https://keygen.warp-generator.workers.dev/')
    
    if [ -z "$response" ]; then
        log_error "Failed to fetch keys from generator"
        exit 1
    fi
    
    PUBLIC_KEY=$(echo "$response" | grep "PublicKey:" | awk '{print $2}')
    PRIVATE_KEY=$(echo "$response" | grep "PrivateKey:" | awk '{print $2}')
    
    if [ -z "$PUBLIC_KEY" ] || [ -z "$PRIVATE_KEY" ]; then
        log_error "Failed to parse keys from response"
        log_error "Response: $response"
        exit 1
    fi
    
    log_info "Keys fetched successfully"
}

# Create the amnezia WireGuard interface
create_interface() {
    local iface_name="$1"
    
    log_info "Creating interface: ${iface_name}"
    
    # Create the interface
    uci set "network.${iface_name}=interface"
    uci set "network.${iface_name}.proto=amneziawg"
    
    # Add peer configuration
    uci add network "amneziawg_${iface_name}"
    uci set "network.@amneziawg_${iface_name}[-1].description=Imported peer configuration"
    uci set "network.@amneziawg_${iface_name}[-1].public_key=${PUBLIC_KEY}"
    uci add_list "network.@amneziawg_${iface_name}[-1].allowed_ips=0.0.0.0/0"
    uci add_list "network.@amneziawg_${iface_name}[-1].allowed_ips=::/0"
    uci set "network.@amneziawg_${iface_name}[-1].endpoint_host=${ENDPOINT_HOST}"
    uci set "network.@amneziawg_${iface_name}[-1].endpoint_port=${ENDPOINT_PORT}"
    
    # Set interface keys and addresses
    uci set "network.${iface_name}.private_key=${PRIVATE_KEY}"
    uci add_list "network.${iface_name}.addresses=172.16.0.2"
    uci add_list "network.${iface_name}.addresses=2606:4700:110:8c0f:698:7f1b:c7ac:a5"
    
    # Amnezia WireGuard specific settings
    uci set "network.${iface_name}.awg_jc=4"
    uci set "network.${iface_name}.awg_jmin=40"
    uci set "network.${iface_name}.awg_jmax=70"
    uci set "network.${iface_name}.awg_s1=0"
    uci set "network.${iface_name}.awg_s2=0"
    uci set "network.${iface_name}.awg_h1=1"
    uci set "network.${iface_name}.awg_h2=2"
    uci set "network.${iface_name}.awg_h3=3"
    uci set "network.${iface_name}.awg_h4=4"
    
    # SIP obfuscation headers
    uci set "network.${iface_name}.awg_i1=<b 0x494e56495445207369703a626f624062696c6f78692e636f6d205349502f322e300d0a5669613a205349502f322e302f55445020706333332e61746c616e74612e636f6d3b6272616e63683d7a39684734624b3737366173646864730d0a4d61782d466f7277617264733a2037300d0a546f3a20426f62203c7369703a626f624062696c6f78692e636f6d3e0d0a46726f6d3a20416c696365203c7369703a616c6963654061746c616e74612e636f6d3e3b7461673d313932383330313737340d0a43616c6c2d49443a20613834623463373665363637313040706333332e61746c616e74612e636f6d0d0a435365713a2033313431353920494e564954450d0a436f6e746163743a203c7369703a616c69636540706333332e61746c616e74612e636f6d3e0d0a436f6e74656e742d547970653a206170706c69636174696f6e2f7364700d0a436f6e74656e742d4c656e6774683a20300d0a0d0a>"
    uci set "network.${iface_name}.awg_i2=<b 0x5349502f322e302031303020547279696e670d0a5669613a205349502f322e302f55445020706333332e61746c616e74612e636f6d3b6272616e63683d7a39684734624b3737366173646864730d0a546f3a20426f62203c7369703a626f624062696c6f78692e636f6d3e0d0a46726f6d3a20416c696365203c7369703a616c6963654061746c616e74612e636f6d3e3b7461673d313932383330313737340d0a43616c6c2d49443a20613834623463373665363637313040706333332e61746c616e74612e636f6d0d0a435365713a2033313431353920494e564954450d0a436f6e74656e742d4c656e6774683a20300d0a0d0a>"
    
    # DNS servers
    uci add_list "network.${iface_name}.dns=1.1.1.1"
    uci add_list "network.${iface_name}.dns=1.0.0.1"
    uci add_list "network.${iface_name}.dns=2606:4700:4700::1111"
    uci add_list "network.${iface_name}.dns=2606:4700:4700::1001"
    
    log_info "Interface ${iface_name} created successfully"
}

# Commit changes and restart network
apply_changes() {
    log_info "Committing network configuration..."
    uci commit network
    
    log_info "Restarting network service..."
    /etc/init.d/network restart
    
    log_info "Configuration applied successfully"
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Creates an Amnezia WireGuard VPN interface for Cloudflare WARP on OpenWrt"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -o, --overwrite  Overwrite existing interface if it exists"
    echo "  -n, --dry-run    Show what would be done without making changes"
    echo ""
    echo "Environment variables:"
    echo "  NETWORK_TAG      Interface name (default: warp)"
    echo "  ENDPOINT_HOST    WARP endpoint host (default: engage.cloudflareclient.com)"
    echo "  ENDPOINT_PORT    WARP endpoint port (default: 4500)"
    echo "  OVERWRITE        Set to 'true' to overwrite existing interface"
    echo ""
    echo "Examples:"
    echo "  $0                           # Create 'warp' interface"
    echo "  NETWORK_TAG=warp2 $0         # Create 'warp2' interface"
    echo "  $0 --overwrite               # Overwrite existing 'warp' interface"
    echo "  NETWORK_TAG=myvpn $0 -o      # Create/overwrite 'myvpn' interface"
}

# Main function
main() {
    local dry_run=false
    
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -o|--overwrite)
                OVERWRITE="true"
                shift
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "Configuration:"
    log_info "  Interface name: ${NETWORK_TAG}"
    log_info "  Endpoint: ${ENDPOINT_HOST}:${ENDPOINT_PORT}"
    log_info "  Overwrite: ${OVERWRITE}"
    
    # Check if interface exists
    if check_interface_exists "${NETWORK_TAG}"; then
        if [ "${OVERWRITE}" = "true" ]; then
            log_warn "Interface ${NETWORK_TAG} already exists, will be overwritten"
            if [ "$dry_run" = "false" ]; then
                delete_interface "${NETWORK_TAG}"
            fi
        else
            log_error "Interface ${NETWORK_TAG} already exists. Use --overwrite or set OVERWRITE=true to replace it."
            exit 1
        fi
    fi
    
    if [ "$dry_run" = "true" ]; then
        log_info "[DRY RUN] Would fetch keys and create interface ${NETWORK_TAG}"
        exit 0
    fi
    
    # Fetch keys from generator
    fetch_keys
    
    log_info "Using keys:"
    log_info "  Public Key: ${PUBLIC_KEY}"
    log_info "  Private Key: ${PRIVATE_KEY:0:10}... (truncated)"
    
    # Create the interface
    create_interface "${NETWORK_TAG}"
    
    # Apply changes
    apply_changes
    
    log_info "Done! Interface ${NETWORK_TAG} is now configured."
    log_info "You can check the status with: ifstatus ${NETWORK_TAG}"
}

# Run main function
main "$@"
