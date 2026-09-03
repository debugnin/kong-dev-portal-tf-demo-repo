# Kong Developer Portal - Terraform Configuration

Infrastructure-as-code repository for managing Kong Konnect Developer Portal, Control Plane, and API gateway configuration.

## Overview

This repository manages:

- **Kong Konnect Control Plane**: Control plane for API gateway management
- **Developer Portal**: Self-service portal for API consumers
- **API Catalog**: APIs and docs published from OpenAPI specs in `api-specs/`
- **Authentication**: Basic auth and OIDC (SSO), both enabled, with team-based access control

## Architecture

- **Control Plane**: `konnect_gateway_control_plane.dev_portal_cp` (`CLUSTER_TYPE_HYBRID`)
- **Data Plane**: set manually via `dataplane_api_base_url`
- **Region**: Australia (`au.api.konghq.com`)

## Prerequisites

- Terraform >= 1.0
- Kong Konnect account with admin access
- Konnect API token (personal access token)

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

Review and update `terraform.tfvars` with your environment-specific values (OIDC issuer/client, `dataplane_api_base_url`, etc.). This file is gitignored since it holds the OIDC client secret.

### 4. Plan and Apply

```bash
terraform plan
terraform apply
```

## Directory Structure

```
.
├── providers.tf                      # Konnect provider configuration
├── variables.tf                      # Variable definitions
├── terraform.tfvars                  # Variable values (gitignored, environment-specific)
├── dev-portal-control-plane.tf       # Control plane, global plugins (ACE, CORS)
├── dev-portal-setup.tf               # Portal, teams, OIDC/basic-auth, role assignments
├── dev-portal-api-catalog.tf         # API catalog and auth strategy configuration
├── outputs.tf                        # Terraform outputs
├── scripts/
│   └── deck-sync.sh                  # Syncs gateway routes/plugins (mocking, openid-connect) to the control plane
├── api-specs/                        # OpenAPI specifications
│   ├── flights/                         # KongAir Flights API
│   └── bookings/                     # KongAir Bookings API
├── dev-portal/                       # Portal customization
│   ├── pages/                        # Portal pages (markdown)
│   ├── snippets/                     # Portal snippets (HTML/JS)
│   └── image-assets/                 # Portal logo and images
└── .gitignore                        # Git ignore patterns
```

## CORS Configuration

The control plane includes a global CORS plugin configured to:

- Allow all origins (`*`)
- Support preflight OPTIONS requests
- Allow common HTTP methods (GET, POST, PUT, PATCH, DELETE, OPTIONS)
- Allow custom headers including `sortOrder`
- Set `preflight_continue: false` to handle OPTIONS at plugin level

## API Specifications

Each directory under `api-specs/` holds an OpenAPI spec (`openapi.yaml`) and a companion `additional-doc.md`, both published to the portal by `dev-portal-api-catalog.tf`:

- Public specs live under `api-specs/public/<slug>/`
- Private specs live under `api-specs/<slug>/`
- The `servers` URL in each published spec is rewritten to `var.dataplane_api_base_url`

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

## Gateway Plugin Sync (`scripts/deck-sync.sh`)

Converts each OpenAPI spec to deck format and pushes it to the control plane with `deck gateway sync`, injecting a `mocking` plugin per service and, for private APIs, an `openid-connect` plugin per route requiring the matching `<api>:read`/`<api>:write` scope. Terraform does not run this script — invoke it manually after applying the auth strategy changes in `dev-portal-api-catalog.tf`.

Required environment variables:

- `KONNECT_TOKEN` — Konnect personal access token
- `CP_NAME` — target control plane name
- `APP_AUTH_OIDC_ISSUER` — must match `var.app_auth_oidc_issuer`
- `APP_AUTH_OIDC_AUDIENCE` — must match `var.app_auth_oidc_audience`; enforced via the injected plugin's `audience`/`audience_required` config so tokens issued for a different API are rejected

Optional: `KONNECT_ADDR` (defaults to `https://au.api.konghq.com`).

```bash
export KONNECT_TOKEN="your-konnect-personal-access-token"
export CP_NAME="your-control-plane-name"
export APP_AUTH_OIDC_ISSUER="https://dev-xxxx.au.auth0.com/"
export APP_AUTH_OIDC_AUDIENCE="https://kongair.com/api/v1"
./scripts/deck-sync.sh
```

## Portal Teams and Access Control

The portal includes team-based access control with both basic auth and OIDC (SSO) login enabled:

**Teams**:

- `portal-admin`: Full portal administration
- `<api>-read` / `<api>-write` per API in the catalog (e.g. `flights-read`, `flights-write`) — generated automatically from `api-specs/`

**OIDC Provider**: Configured via `dev_portal_oidc_*` variables; team-group mappings assign portal roles from IdP groups.

## Development Workflow

1. **Add/update OpenAPI specs** in `api-specs/<slug>/openapi.yaml` with a matching `additional-doc.md`, for example `api-specs/bookings/openapi.yaml`
2. **Modify Terraform config** for infrastructure changes
3. **Plan and apply** Terraform changes
4. **Commit and push** to version control

## Troubleshooting

### CORS Issues

- Verify CORS plugin is enabled on the control plane
- Check that OPTIONS routes exist for preflight requests
- Ensure `preflight_continue: false` in CORS plugin config

### Authentication Issues

- Verify `KONNECT_TOKEN` is set and valid
- Check token has appropriate permissions (admin or gateway admin)
- Both basic auth and OIDC are enabled on the portal — see `dev-portal-setup.tf`'s `dev_portal_oidc_config` provisioner

## Contributing

1. Create a feature branch from `main`
2. Make changes following the resource management strategy
3. Test changes in dev/qa environment
4. Submit PR for review
5. Merge to main after approval

## License

Internal use only - Acme Corp
