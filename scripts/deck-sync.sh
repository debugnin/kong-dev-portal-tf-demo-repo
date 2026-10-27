#!/usr/bin/env bash
set -euo pipefail

# Required
: "${KONNECT_TOKEN:?KONNECT_TOKEN is required}"
: "${CP_NAME:?CP_NAME is required}"

KONNECT_ADDR="${KONNECT_ADDR:-https://au.api.konghq.com}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# Discover API specs the same way the Terraform catalog does:
#   api-specs/<slug>/openapi.yaml         (private)
#   api-specs/public/<slug>/openapi.yaml  (public)
# The slug is the spec's parent directory name. Uses pure bash globbing so it
# works on minimal CI images without find/basename/dirname.
declare -A SPEC_OF
APIS=()
for spec in "${REPO_DIR}"/api-specs/*/openapi.yaml "${REPO_DIR}"/api-specs/public/*/openapi.yaml; do
  [ -e "${spec}" ] || continue
  dir="${spec%/openapi.yaml}"
  slug="${dir##*/}"
  SPEC_OF["${slug}"]="${spec}"
  APIS+=("${slug}")
done

# 1. Convert each OAS spec to deck format and inject a mock plugin per service
for api in "${APIS[@]}"; do
  spec_file="${SPEC_OF[${api}]}"

  echo "[${api}] Converting OAS spec to deck format..."
  deck file openapi2kong \
    --spec "${spec_file}" \
    --output-file "${TEMP_DIR}/${api}.yaml"

  echo "[${api}] Injecting mocking plugin..."
  python3 - "${TEMP_DIR}/${api}.yaml" "${spec_file}" "${TEMP_DIR}/${api}-final.yaml" "${api}" << 'PYEOF'
import sys, yaml

state_file, spec_file, output_file, api = sys.argv[1:5]

with open(spec_file) as f:
    spec_content = f.read()

with open(state_file) as f:
    state = yaml.safe_load(f)

# Scope/audience enforcement is no longer injected here - it's handled by
# the control plane's ACE plugin (see dev-portal-control-plane.tf), which
# enforces the auth strategy selected on each API's publication instead of
# per-route openid-connect plugins.
plugin = {"name": "mocking", "config": {"api_specification": spec_content}}
for service in state.get("services", []):
    service.setdefault("plugins", []).append(plugin)

    routes = service.get("routes", [])

    # Kong's router matches path *and* method before any plugin (including
    # CORS) runs, so a CORS preflight OPTIONS request 404s unless some route
    # accepts it. Rather than widening every real route's methods, add one
    # dedicated catch-all route per service covering all of its paths.
    paths = sorted({p for route in routes for p in route.get("paths", [])})
    if paths:
        routes.append({
            "name": f"{service['name']}_preflight",
            "methods": ["OPTIONS"],
            "paths": paths,
        })

with open(output_file, "w") as f:
    yaml.dump(state, f, default_flow_style=False, allow_unicode=True)
PYEOF
done

# 2. Merge all service configs
echo "Merging service configurations..."
# shellcheck disable=SC2046
deck file merge $(printf "${TEMP_DIR}/%s-final.yaml " "${APIS[@]}") \
  --output-file "${TEMP_DIR}/merged.yaml"

# 3. Add tags to all deck-managed resources
echo "Tagging deck-managed resources..."
deck file add-tags \
  --state "${TEMP_DIR}/merged.yaml" \
  --output-file "${TEMP_DIR}/tagged.yaml" \
  managed-by-deck

# 4. Push to Serverless CP (skip consumers to avoid conflicts with Terraform)
echo "Syncing to '${CP_NAME}'..."
deck gateway sync "${TEMP_DIR}/tagged.yaml" \
  --konnect-token "${KONNECT_TOKEN}" \
  --konnect-addr "${KONNECT_ADDR}" \
  --konnect-control-plane-name "${CP_NAME}" \
  --skip-consumers \
  --select-tag managed-by-deck

echo "Done."
