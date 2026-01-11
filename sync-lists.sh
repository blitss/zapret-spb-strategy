#!/bin/sh

# Sync script for zapret lists
# Fetches CDN IP ranges and RKN blocked domains

set -e

IPSET_DIR="ipset"
mkdir -p "$IPSET_DIR"

echo "Fetching CDN IP ranges (Cloudflare, Amazon, Hetzner, etc.)..."
curl -fsSL "https://raw.githubusercontent.com/123jjck/cdn-ip-ranges/main/all/all_plain_ipv4.txt" -o "$IPSET_DIR/cust2.txt"

echo "Fetching RKN blocked domains list..."
curl -fsSL "https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/RKN/List.txt" -o "$IPSET_DIR/zapret-hosts-user.txt"

echo "Fetching WhatsApp IP ranges..."
curl -fsSL "https://raw.githubusercontent.com/HybridNetworks/whatsapp-cidr/main/WhatsApp/whatsapp_cidr_ipv4.txt" | grep -v '^#' | grep -v '^$' > "$IPSET_DIR/wa-ipset.txt"

echo "All lists updated successfully!"
