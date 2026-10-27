#!/usr/bin/env bash
set -euo pipefail

# Brings up a local Kong Gateway Data Plane (Docker) and connects it, in
# hybrid mode, to the Konnect-hosted control plane managed by this repo's
# Terraform config (konnect_gateway_control_plane.dev_portal_cp). This is
# the "backend" that var.dataplane_api_base_url (default
# http://localhost:8000) points at for the Dev Portal's "Try it" console
# and for scripts/deck-sync.sh-managed routes to actually serve traffic.
#
# What it does:
#   1. Generates a self-signed TLS keypair for this DP (./cert/, gitignored)
#      if one doesn't already exist.
#   2. Registers the certificate's public half with Konnect as a pinned
#      client certificate for the target control plane (idempotent - skips
#      if a certificate with the same fingerprint is already registered).
#   3. Looks up the control plane's cluster/telemetry endpoints by name and
#      writes them to ./cert/cp-endpoints.env (gitignored).
#   4. Runs `docker compose up -d` for the data-plane service defined in
#      docker-compose.yml, using that env file plus KONG_LICENSE_DATA from
#      the environment (ACE and openid-connect are Enterprise-only plugins
#      and require a valid license to load).
#
# Required environment variables:
#   KONNECT_TOKEN     - Konnect personal access token
#   CP_NAME           - control plane name (matches dev_portal_cp_name, e.g.
#                        "Dev Portal Control Plane")
#   KONG_LICENSE_DATA - Kong Enterprise license, as a single-line JSON string
#
# Optional:
#   KONNECT_ADDR      - defaults to https://au.api.konghq.com
#   KONG_IMAGE         - defaults to kong/kong-gateway:3.9

: "${KONNECT_TOKEN:?KONNECT_TOKEN is required}"
: "${CP_NAME:?CP_NAME is required}"
: "${KONG_LICENSE_DATA:?KONG_LICENSE_DATA is required (ACE/openid-connect are Enterprise-only plugins)}"

KONNECT_ADDR="${KONNECT_ADDR:-https://au.api.konghq.com}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
CERT_DIR="${REPO_DIR}/cert"
mkdir -p "${CERT_DIR}"

# 1. Generate a self-signed keypair for this DP if one doesn't exist yet.
if [ ! -f "${CERT_DIR}/tls.crt" ] || [ ! -f "${CERT_DIR}/tls.key" ]; then
  echo "Generating self-signed data-plane certificate in ${CERT_DIR}..."
  openssl req -new -x509 -nodes -newkey rsa:2048 \
    -subj "/CN=kong-dp-local/C=AU" \
    -keyout "${CERT_DIR}/tls.key" \
    -out "${CERT_DIR}/tls.crt" \
    -days 3650
else
  echo "Reusing existing certificate at ${CERT_DIR}/tls.crt"
fi

# 2. Look up the control plane by name.
echo "Looking up control plane '${CP_NAME}'..."
CP_JSON=$(curl -s -H "Authorization: Bearer ${KONNECT_TOKEN}" \
  --get --data-urlencode "filter[name][eq]=${CP_NAME}" \
  "${KONNECT_ADDR}/v2/control-planes/")

CP_ID=$(echo "${CP_JSON}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data'][0]['id'])")
CP_ENDPOINT=$(echo "${CP_JSON}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data'][0]['config']['control_plane_endpoint'])")
TP_ENDPOINT=$(echo "${CP_JSON}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data'][0]['config']['telemetry_endpoint'])")

if [ -z "${CP_ID}" ]; then
  echo "ERROR: no control plane named '${CP_NAME}' found." >&2
  exit 1
fi

echo "control_plane_id=${CP_ID}"

# 3. Register the certificate with Konnect, skipping if an identical
#    certificate (same modulus) is already registered.
EXISTING_FILE=$(mktemp)
trap 'rm -f "${EXISTING_FILE}" /tmp/_existing_cert.pem' EXIT
curl -s -H "Authorization: Bearer ${KONNECT_TOKEN}" \
  "${KONNECT_ADDR}/v2/control-planes/${CP_ID}/dp-client-certificates" > "${EXISTING_FILE}"

ALREADY_REGISTERED=$(python3 - "${CERT_DIR}/tls.crt" "${EXISTING_FILE}" << 'PYEOF'
import json, subprocess, sys
cert_path, existing_file = sys.argv[1], sys.argv[2]
with open(existing_file) as f:
    existing = json.load(f)
new_modulus = subprocess.check_output(["openssl", "x509", "-noout", "-modulus", "-in", cert_path]).decode()
for item in existing.get("items", []):
    with open("/tmp/_existing_cert.pem", "w") as f:
        f.write(item["cert"])
    existing_modulus = subprocess.check_output(["openssl", "x509", "-noout", "-modulus", "-in", "/tmp/_existing_cert.pem"]).decode()
    if existing_modulus == new_modulus:
        print("yes")
        break
else:
    print("no")
PYEOF
)

if [ "${ALREADY_REGISTERED}" = "yes" ]; then
  echo "Certificate already registered with control plane, skipping registration."
else
  echo "Registering certificate with control plane..."
  CERT_JSON=$(python3 -c "import json; print(json.dumps(open('${CERT_DIR}/tls.crt').read()))")
  HTTP_STATUS=$(curl -s -o /tmp/_register_resp.json -w "%{http_code}" -X POST \
    -H "Authorization: Bearer ${KONNECT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"cert\": ${CERT_JSON}}" \
    "${KONNECT_ADDR}/v2/control-planes/${CP_ID}/dp-client-certificates")
  if [ "${HTTP_STATUS}" -ge 400 ]; then
    echo "ERROR: certificate registration returned ${HTTP_STATUS}:" >&2
    cat /tmp/_register_resp.json >&2
    exit 1
  fi
fi

# 4. Write resolved endpoints (host only, no scheme) for docker-compose.
CP_HOST=$(echo "${CP_ENDPOINT}" | sed -E 's#^https?://##')
TP_HOST=$(echo "${TP_ENDPOINT}" | sed -E 's#^https?://##')

cat > "${CERT_DIR}/cp-endpoints.env" << EOF
CP_HOST=${CP_HOST}
TP_HOST=${TP_HOST}
EOF

echo "Wrote ${CERT_DIR}/cp-endpoints.env (CP_HOST=${CP_HOST}, TP_HOST=${TP_HOST})"

# 5. Start the data plane.
echo "Starting local data plane via docker compose..."
cd "${REPO_DIR}"
docker compose --env-file "${CERT_DIR}/cp-endpoints.env" up -d

echo "Done. Tail logs with: docker compose logs -f kong-dp"
echo "Proxy should be reachable at http://localhost:8000 once the DP finishes connecting (check Konnect's Runtime Manager or 'docker compose logs kong-dp')."
