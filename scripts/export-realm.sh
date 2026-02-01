#!/bin/bash
# ============================================================
# Export Keycloak Realm Configuration
# ============================================================

set -euo pipefail

REALM="${1:-finapp}"
OUTPUT_DIR="${2:-realm-config/exported}"
KC_ADMIN_USER="${KC_ADMIN_USER:-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-admin}"
KC_URL="${KC_URL:-http://localhost:8080}"

echo "Exporting realm: $REALM"
echo "Output directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get admin token
TOKEN=$(curl -s -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=$KC_ADMIN_USER" \
    -d "password=$KC_ADMIN_PASSWORD" | jq -r '.access_token')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo "Error: Failed to get admin token"
    exit 1
fi

# Export realm
curl -s -X GET "$KC_URL/admin/realms/$REALM" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json" \
    | jq '.' > "$OUTPUT_DIR/${REALM}-realm.json"

echo "Realm exported to: $OUTPUT_DIR/${REALM}-realm.json"

# Export clients
curl -s -X GET "$KC_URL/admin/realms/$REALM/clients" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json" \
    | jq '.' > "$OUTPUT_DIR/${REALM}-clients.json"

echo "Clients exported to: $OUTPUT_DIR/${REALM}-clients.json"

# Export roles
curl -s -X GET "$KC_URL/admin/realms/$REALM/roles" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json" \
    | jq '.' > "$OUTPUT_DIR/${REALM}-roles.json"

echo "Roles exported to: $OUTPUT_DIR/${REALM}-roles.json"

echo "Export completed!"
