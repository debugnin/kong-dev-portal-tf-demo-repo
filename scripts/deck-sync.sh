#!/usr/bin/env bash
set -euo pipefail

# Required
: "${KONNECT_TOKEN:?KONNECT_TOKEN is required}"
: "${CP_NAME:?CP_NAME is required}"
: "${APP_AUTH_OIDC_ISSUER:?APP_AUTH_OIDC_ISSUER is required}"
: "${APP_AUTH_OIDC_AUDIENCE:?APP_AUTH_OIDC_AUDIENCE is required}"

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

  echo "[${api}] Injecting mocking and openid-connect plugins..."
  python3 - "${TEMP_DIR}/${api}.yaml" "${spec_file}" "${TEMP_DIR}/${api}-final.yaml" "${api}" "${APP_AUTH_OIDC_ISSUER}" "${APP_AUTH_OIDC_AUDIENCE}" << 'PYEOF'
import sys, yaml

state_file, spec_file, output_file, api, issuer, audience = sys.argv[1:7]

with open(spec_file) as f:
    spec_content = f.read()
    spec = yaml.safe_load(spec_content)

with open(state_file) as f:
    state = yaml.safe_load(f)

# Public specs (api-specs/public/<slug>/openapi.yaml) are unauthenticated by
# design - only private APIs get scope enforcement.
is_public = "/api-specs/public/" in spec_file
WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}
HTTP_METHODS = {"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"}

# Operations explicitly marked `security: []` in the spec (e.g. health
# checks) must stay open even though the rest of the API requires a scope.
unauthenticated_ops = {
    (path, method.upper())
    for path, path_item in (spec.get("paths") or {}).items()
    for method, op in path_item.items()
    if method.upper() in HTTP_METHODS and isinstance(op, dict) and op.get("security") == []
}


def spec_path(kong_path):
    # openapi2kong renders concrete paths as "~/bookings/health$". Templated
    # paths become named-capture regexes (e.g. "{flightNumber}" ->
    # "(?<flightnumber>[^#?/]+)") that this won't match back to the spec's
    # "/flights/{flightNumber}" key, so those routes always fail the
    # unauthenticated_ops lookup below and keep requiring a scope - the
    # secure-by-default outcome, and fine as long as no templated route
    # needs `security: []` (none currently do).
    return kong_path[1:-1] if kong_path.startswith("~") and kong_path.endswith("$") else kong_path


plugin = {"name": "mocking", "config": {"api_specification": spec_content}}
for service in state.get("services", []):
    service.setdefault("plugins", []).append(plugin)

    routes = service.get("routes", [])

    if not is_public:
        # Scope-based authorization: a route needs "<api>:write" if it
        # allows any mutating method, otherwise "<api>:read" - unless every
        # method/path on it is explicitly unauthenticated in the spec.
        for route in routes:
            methods = {m.upper() for m in route.get("methods", [])}
            paths = {spec_path(p) for p in route.get("paths", [])}
            if methods and paths and all((p, m) in unauthenticated_ops for p in paths for m in methods):
                continue
            scope = f"{api}:write" if methods & WRITE_METHODS else f"{api}:read"
            route.setdefault("plugins", []).append({
                "name": "openid-connect",
                "config": {
                    "issuer": issuer,
                    "auth_methods": ["bearer"],
                    "scopes_required": [scope],
                    # Reject tokens issued for a different API (aud claim
                    # mismatch) - without this, any token from this Auth0
                    # tenant with the right scope name would be accepted
                    # regardless of which API resource it was issued for.
                    "audience": [audience],
                    "audience_required": True,
                    # This data plane enforces global TLS verification and
                    # rejects any plugin that leaves ssl_verify at its
                    # (disabled) default - must be set explicitly.
                    "ssl_verify": True,
                },
            })

    # Kong's router matches path *and* method before any plugin (including
    # CORS) runs, so a CORS preflight OPTIONS request 404s unless some route
    # accepts it. Rather than widening every real route's methods, add one
    # dedicated catch-all route per service covering all of its paths. Added
    # after scope enforcement above so the preflight route stays open.
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
