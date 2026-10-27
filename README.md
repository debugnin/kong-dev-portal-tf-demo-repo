# Kong Developer Portal - Terraform Configuration

Infrastructure-as-code repository for managing Kong Konnect Developer Portal, Control Plane, and API gateway configuration.

## Overview

This repository manages:

- **Kong Konnect Control Plane**: Control plane for API gateway management (`CLUSTER_TYPE_HYBRID`), with global ACE and CORS plugins
- **Developer Portal**: Self-service portal for API consumers
- **API Catalog**: APIs and docs published from OpenAPI specs in `api-specs/`
- **Authentication**: Basic auth only for portal login; applications authenticate to published APIs via a Konnect-issued API key

Terraform manages everything in Konnect except the actual Gateway Services/Routes/mocking plugin behind each API, which are pushed separately by `scripts/deck-sync.sh` (see below), and the local Kong Gateway Data Plane that serves the proxied traffic, which runs via Docker (see "Local Data Plane").

## Architecture

- **Control Plane**: `konnect_gateway_control_plane.dev_portal_cp` (`CLUSTER_TYPE_HYBRID`) — a hybrid-mode control plane has no built-in proxy; a Data Plane node must connect to it to actually serve traffic
- **Data Plane**: a local Kong Gateway container, started with `scripts/start-local-dp.sh` (see "Local Data Plane" below), proxying on `var.dataplane_api_base_url` (default `http://localhost:8000`)
- **Region**: Australia (`au.api.konghq.com`)

## Prerequisites

- Terraform >= 1.0
- Kong Konnect account with admin access
- Konnect API token (personal access token)
- [`deck`](https://github.com/Kong/deck) CLI (for `scripts/deck-sync.sh`)
- Docker + Docker Compose (for the local Data Plane)
- A Kong Enterprise license (ACE and openid-connect are Enterprise-only plugins)

## Getting Started

### 1. Authentication

Export your Konnect token:

```bash
export KONNECT_TOKEN="your-konnect-personal-access-token"
```

### 2. Initialize Terraform

```bash
terraform init
```

State is stored locally (`terraform.tfstate`) — no remote backend is configured.

### 3. Configure Variables

Review and update `terraform.tfvars` with your environment-specific values (`dataplane_api_base_url`, etc.). This file is gitignored.

### 4. Plan and Apply

```bash
terraform plan
terraform apply
```

### 5. Sync Gateway Routes (`scripts/deck-sync.sh`)

```bash
export KONNECT_TOKEN="your-konnect-personal-access-token"
export CP_NAME="Dev Portal Control Plane"
./scripts/deck-sync.sh
```

### 6. Start the Local Data Plane (Docker)

```bash
export KONNECT_TOKEN="your-konnect-personal-access-token"
export CP_NAME="Dev Portal Control Plane"
export KONG_LICENSE_DATA="$(cat /path/to/license.json)"
./scripts/start-local-dp.sh
```

See "Local Data Plane" below for details.

## Directory Structure

```
.
├── providers.tf                      # Konnect provider configuration
├── variables.tf                      # Variable definitions
├── terraform.tfvars                  # Variable values (gitignored, environment-specific)
├── dev-portal-control-plane.tf       # Control plane, global plugins (ACE, CORS)
│                                      # ACE enforces each API's publication auth strategy for the whole control plane
├── dev-portal-setup.tf               # Portal, teams, basic-auth login, role assignments
├── dev-portal-api-catalog.tf         # API catalog and auth strategy configuration
├── outputs.tf                        # Terraform outputs
├── docker-compose.yml                # Local Kong Gateway Data Plane (hybrid mode)
├── scripts/
│   ├── deck-sync.sh                  # Syncs gateway routes/plugins (mocking) to the control plane
│   └── start-local-dp.sh             # Generates/registers a DP cert and starts the local Data Plane via Docker
├── cert/                             # Generated DP keypair + resolved CP endpoints (gitignored, created by start-local-dp.sh)
├── api-specs/                        # OpenAPI specifications
│   ├── flights/                      # KongAir Flights API
│   └── bookings/                     # KongAir Bookings API
├── dev-portal/                       # Portal customization
│   ├── pages/                        # Portal pages (markdown)
│   ├── snippets/                     # Portal snippets (HTML/JS)
│   └── image-assets/                 # Portal logo and images
└── .gitignore                        # Git ignore patterns
```

## CORS Configuration

The control plane includes a global CORS plugin (`konnect_gateway_plugin_cors.plugin_cors` in `dev-portal-control-plane.tf`) configured to:

- Allow all origins (`*`)
- Support preflight OPTIONS requests
- Allow common HTTP methods (GET, POST, PUT, PATCH, DELETE, OPTIONS)
- Allow all request/response headers (`*`)
- Set `preflight_continue: false` to handle OPTIONS at plugin level

Kong's router matches path *and* method before any plugin runs, so each Gateway Service also needs a route that actually accepts `OPTIONS` for CORS to kick in on preflight requests — `scripts/deck-sync.sh` adds one catch-all `OPTIONS` route per service covering all of its paths (see "Gateway Plugin Sync" below). A plain `OPTIONS` request without `Origin`/`Access-Control-Request-Method` headers is not treated as a CORS preflight and will 404 from the `mocking` plugin instead, since no OpenAPI operation defines an `OPTIONS` method — that's expected.

## API Specifications

Each directory under `api-specs/` holds an OpenAPI spec (`openapi.yaml`) and a companion `additional-doc.md`, both published to the portal by `dev-portal-api-catalog.tf`:

- Public specs live under `api-specs/public/<slug>/`
- Private specs live under `api-specs/<slug>/`
- The `servers` URL in each published spec is rewritten to `var.dataplane_api_base_url`
- The `__DATAPLANE_BASE_URL__` placeholder in each `additional-doc.md` is resolved to `var.dataplane_api_base_url` at apply time — never hardcode a real/environment-specific URL into a committed doc file

### API Slugs

Each API gets its own top-level directory:

```text
api-specs/flights/openapi.yaml
api-specs/flights/additional-doc.md
api-specs/bookings/openapi.yaml
api-specs/bookings/additional-doc.md
```

The directory name becomes the Konnect API slug and drives generated team names, for example:

```text
flights
flights-read
flights-write
bookings
bookings-read
bookings-write
```

The OpenAPI `info.version` remains the API version source of truth inside the spec.

## Authentication Model

- **Dev Portal login**: basic auth only (`konnect_portal_auth.dev_portal` in `dev-portal-setup.tf`). No SSO/OIDC identity provider is configured; team membership is assigned directly by a Konnect Identity Admin (`konnect_mapping_enabled = true`) rather than mapped from IdP groups.
- **Application → API auth**: a single API-key application auth strategy (`konnect_application_auth_strategy.api_key` in `dev-portal-api-catalog.tf`, `key_auth`, header name `apikey`). Developers register an application in the Dev Portal and are issued an API key directly — no external identity provider or Dynamic Client Registration is involved. Applications send the key on the `apikey` header on every request.
- **Enforcement**: the control plane's `konnect_gateway_plugin_ace` (ACE) plugin — defined in `dev-portal-control-plane.tf` — enforces the auth strategy selected on each API's publication (`konnect_api_publication.publication` in `dev-portal-api-catalog.tf`) across the whole control plane, with `match_policy = "if_present"` so only requests matching a published API operation are access-controlled. Public APIs (`api-specs/public/<slug>/`) are published with no auth strategy and are unauthenticated.
- ACE requires each API to be linked to the control plane via `konnect_api_implementation.implementation` (control-plane-level reference) — without it, ACE's operations router can't resolve the request to a published operation and, with `match_policy = "if_present"`, the request bypasses auth entirely.

## Gateway Plugin Sync (`scripts/deck-sync.sh`)

Converts each OpenAPI spec to deck format and pushes it to the control plane with `deck gateway sync`, injecting a `mocking` plugin per service (so the demo APIs return realistic fake data without a real backend) and one catch-all `OPTIONS` route per service for CORS preflight. Terraform does not run this script — invoke it manually after applying the catalog/publication changes in `dev-portal-api-catalog.tf`, and again any time a spec's paths/operations change or the control plane is recreated (routes/services are not part of Terraform state).

Authorization is not injected per-route by this script — see "Authentication Model" above.

Required environment variables:

- `KONNECT_TOKEN` — Konnect personal access token
- `CP_NAME` — target control plane name

Optional: `KONNECT_ADDR` (defaults to `https://au.api.konghq.com`).

```bash
export KONNECT_TOKEN="your-konnect-personal-access-token"
export CP_NAME="your-control-plane-name"
./scripts/deck-sync.sh
```

## Local Data Plane (Docker)

`konnect_gateway_control_plane.dev_portal_cp` runs in `CLUSTER_TYPE_HYBRID`, which means Konnect only hosts the control plane (config storage/distribution) — a real Kong Gateway Data Plane node must connect to it to actually proxy traffic on `var.dataplane_api_base_url` (default `http://localhost:8000`). This repo includes a `docker-compose.yml` plus a helper script, `scripts/start-local-dp.sh`, that automates the whole connection flow:

1. Generates a self-signed TLS keypair under `./cert/` (gitignored) if one doesn't already exist
2. Registers the certificate's public half with Konnect as a pinned client certificate for the target control plane (`POST /v2/control-planes/{id}/dp-client-certificates`), skipping registration if an identical certificate is already registered
3. Looks up the control plane's cluster/telemetry endpoints by name and writes them to `./cert/cp-endpoints.env` (gitignored)
4. Runs `docker compose up -d` for the `kong-dp` service in `docker-compose.yml`, using that env file for the endpoints and `KONG_LICENSE_DATA` from the environment

```bash
export KONNECT_TOKEN="your-konnect-personal-access-token"
export CP_NAME="Dev Portal Control Plane"
export KONG_LICENSE_DATA="$(cat /path/to/license.json)"
./scripts/start-local-dp.sh
```

Once the container connects (check `docker compose logs -f kong-dp` or the control plane's Runtime Manager page in Konnect), the APIs published by `dev-portal-api-catalog.tf` and synced by `scripts/deck-sync.sh` become reachable at `http://localhost:8000`:

```bash
curl http://localhost:8000/flights          # 401 without an apikey header; mock data with one
curl http://localhost:8000/bookings
```

Notes:

- **A valid, non-expired Kong Enterprise license is required.** ACE (access control enforcement) silently stops enforcing auth if the license is expired or missing — the Gateway still starts and proxies traffic, but every request succeeds regardless of the `apikey` header, which looks like a config bug but isn't.
- Only one process can bind `localhost:8000` at a time — stop any other local Kong container (e.g. one started manually via the Konnect UI's quickstart command) before running `start-local-dp.sh`, or override the port by setting `KONG_IMAGE`/editing the `ports:` mapping in `docker-compose.yml`.
- The control plane's own cert/key pair is per-control-plane: if the control plane is destroyed and recreated (e.g. via `terraform destroy`/`terraform apply`), delete `./cert/` and re-run `start-local-dp.sh` to re-resolve the new endpoints and re-register a certificate. If the control plane's `auth_type` is `pinned_client_certs`, Konnect may already have auto-generated a certificate for its own quickstart UI flow — `start-local-dp.sh` doesn't rely on that; it generates and registers its own.
- `docker compose down` stops the local Data Plane; it disappears from the control plane's Runtime Manager shortly after.

## Portal Teams and Access Control

The portal includes team-based access control with basic-auth-only login (no SSO/OIDC identity provider):

**Teams**:

- `portal-admin`: Full portal administration
- `<api>-read` / `<api>-write` per API in the catalog (e.g. `flights-read`, `flights-write`) — generated automatically from `api-specs/`

Team membership is assigned directly by a Konnect Identity Admin (`konnect_mapping_enabled = true` on `konnect_portal_auth.dev_portal`) rather than mapped from IdP groups.

## Development Workflow

1. **Add/update OpenAPI specs** in `api-specs/<slug>/openapi.yaml` with a matching `additional-doc.md`, for example `api-specs/bookings/openapi.yaml`
2. **Modify Terraform config** for infrastructure changes
3. **Plan and apply** Terraform changes
4. **Re-run `scripts/deck-sync.sh`** if any spec's paths/operations changed
5. **Commit and push** to version control

## Troubleshooting

### CORS Issues

- Verify the CORS plugin is enabled on the control plane
- Check that an `OPTIONS` route exists on the relevant Gateway Service for preflight requests (added automatically by `scripts/deck-sync.sh`)
- Ensure `preflight_continue: false` in the CORS plugin config
- A preflight request needs both `Origin` and `Access-Control-Request-Method` headers — a bare `OPTIONS` request without them is not treated as a preflight and will 404

### Authentication Issues

- Verify `KONNECT_TOKEN` is set and valid; check it has appropriate permissions (admin or gateway admin)
- Only basic auth is enabled on the portal — see `konnect_portal_auth.dev_portal` in `dev-portal-setup.tf`
- Applications authenticate to APIs with the API key issued when they're registered in the portal (`konnect_application_auth_strategy.api_key` in `dev-portal-api-catalog.tf`), sent on the `apikey` header
- If every request succeeds regardless of the `apikey` header, check the local Data Plane's logs for an expired-license warning — ACE stops enforcing auth without a valid license (see "Local Data Plane" above)

### "Try it" Console / Local Data Plane Issues

- `dataplane_api_base_url` (default `http://localhost:8000`) is only reachable from a browser running on the same machine as the local Data Plane — this is a demo-only limitation, not a CORS bug
- If `http://localhost:8000` isn't responding at all, no Data Plane container is running — see "Local Data Plane" above
- If the control plane was recently destroyed/recreated, delete `./cert/` and re-run `scripts/start-local-dp.sh` to pick up the new control plane's endpoints

## Contributing

1. Create a feature branch from `main`
2. Make changes following the resource management strategy
3. Test changes in dev/qa environment
4. Submit PR for review
5. Merge to main after approval

## License

Internal use only - Acme Corp
