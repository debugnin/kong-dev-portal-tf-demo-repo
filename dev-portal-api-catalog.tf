locals {
  # Private API specs live at api-specs/<slug>/openapi.yaml.
  # Public API specs live at api-specs/public/<slug>/openapi.yaml and are
  # published with public (anonymous) visibility.
  api_files = merge(
    {
      # Private: top-level specs only. The "*/openapi.yaml" glob matches a
      # single directory level, so the nested public/ folder is excluded
      # (the explicit guard documents and enforces that).
      for f in fileset("${path.module}/api-specs", "*/openapi.yaml") :
      dirname(f) => { path = f, visibility = "private" }
      if dirname(f) != "public"
    },
    {
      for f in fileset("${path.module}/api-specs", "public/*/openapi.yaml") :
      basename(dirname(f)) => { path = f, visibility = "public" }
    }
  )
  apis = toset(keys(local.api_files))
  api_specs = {
    for slug, meta in local.api_files : slug => yamldecode(file("${path.module}/api-specs/${meta.path}"))
  }
}

# Acme Corp APIs
resource "konnect_api" "api" {
  for_each = local.apis

  name = local.api_specs[each.key].info.title
  slug = each.key
  spec_content = replace(
    replace(
      replace(
        file("${path.module}/api-specs/${local.api_files[each.key].path}"),
        "/servers:\\s*-\\s*url:\\s*\"[^\"]*\"/",
        ""
      ),
      "paths:",
      "servers:\n  - url: \"${var.dataplane_api_base_url}\"\npaths:"
    ),
    "__OIDC_TOKEN_URL__",
    "${trimsuffix(var.app_auth_oidc_issuer, "/")}/oauth/token"
  )
  labels = {
    domain = "acme"
  }
}

# API Docs
resource "konnect_api_document" "doc" {
  for_each = local.apis

  api_id = konnect_api.api[each.key].id
  content = replace(
    replace(
      file("${path.module}/api-specs/${dirname(local.api_files[each.key].path)}/additional-doc.md"),
      "__OIDC_TOKEN_URL__",
      "${trimsuffix(var.app_auth_oidc_issuer, "/")}/oauth/token"
    ),
    "__DATAPLANE_BASE_URL__",
    var.dataplane_api_base_url
  )
  slug = "${each.key}-docs"
  status  = "published"
  title   = "${local.api_specs[each.key].info.title} API Documentation"
}

# Auth0 Dynamic Client Registration provider - manages Auth0 M2M clients on
# behalf of applications registered through the Dev Portal. Requires an
# Auth0 M2M application (Management API scopes: read/create/delete/update on
# clients and client_grants, update:client_keys, plus read:resource_servers
# for use_developer_managed_scopes below) already created out of band in
# Auth0 - Terraform only consumes its client_id/client_secret.
resource "konnect_dcr_provider" "auth0" {
  auth0 = {
    name   = "auth0-dcr"
    issuer = var.app_auth_oidc_issuer
    dcr_config = {
      initial_client_id     = var.app_auth_dcr_client_id
      initial_client_secret = var.app_auth_dcr_client_secret
      # initial_client_audience must be explicit: when unset, Konnect
      # defaults to the bare issuer URL as the M2M token audience, but
      # Auth0's Management API audience is always "{issuer}/api/v2/" (even
      # without a custom domain) - the bare issuer gets rejected with
      # "Service not enabled within domain" (verified directly against this
      # tenant), which is what caused the application-creation "integration
      # error" in the Dev Portal.
      initial_client_audience = "${trimsuffix(var.app_auth_oidc_issuer, "/")}/api/v2/"

      # Lets each developer choose which of the auth strategy's scopes to
      # request when registering an application, instead of every app
      # getting the full fixed set - required for the scope-based
      # authorization demo (different apps, different access).
      use_developer_managed_scopes = true
    }
  }

  # Konnect strips the trailing slash from auth0.issuer on every read
  # regardless of what's submitted, causing a perpetual no-op diff.
  lifecycle {
    ignore_changes = [auth0.issuer]
  }
}

# Application Auth Strategy - OIDC via Auth0 DCR
resource "konnect_application_auth_strategy" "oidc_auth0" {
  openid_connect = {
    name            = "oidc-auth0-dcr"
    display_name    = "Auth0 OIDC (DCR)"
    strategy_type   = "openid_connect"
    dcr_provider_id = konnect_dcr_provider.auth0.id
    configs = {
      openid_connect = {
        issuer = var.app_auth_oidc_issuer
        # One read/write scope pair per API, e.g. "bookings:read" -
        # matches the {api}:{read,write} pairing the deck-sync.sh gateway
        # plugins enforce and the Portal Teams model already uses.
        scopes           = concat(var.app_auth_oidc_scopes, flatten([for api in local.apis : ["${api}:read", "${api}:write"]]))
        auth_methods     = ["client_credentials", "bearer", "session"]
        credential_claim = ["azp"]
        # Auth0 requires an explicit token audience (its /token endpoint
        # otherwise rejects client_credentials grants), and ssl_verify must
        # be explicit for the same reason it is on the gateway's
        # openid-connect plugin (see deck-sync.sh) - neither is a
        # first-class attribute in this provider version, so both are
        # passed through as raw openid-connect plugin config fields.
        additional_properties = jsonencode({
          token_post_args_names  = ["audience"]
          token_post_args_values = [var.app_auth_oidc_audience]
          ssl_verify             = true
        })
      }
    }
  }
}

# API Publishing
resource "konnect_api_publication" "publication" {
  for_each = local.apis

  api_id    = konnect_api.api[each.key].id
  portal_id = konnect_portal.dev_portal.id

  auto_approve_registrations = true
  visibility                 = local.api_files[each.key].visibility
  # Public APIs are unauthenticated, so the attribute is omitted (null) rather
  # than set to []: the provider rejects an empty list (min 1 element).
  # Private APIs require Auth0-issued OIDC credentials via DCR.
  auth_strategy_ids = local.api_files[each.key].visibility == "public" ? null : [konnect_application_auth_strategy.oidc_auth0.id]
}

# Links each catalog API to the Dev Portal control plane
# (konnect_gateway_control_plane.dev_portal_cp, defined in
# dev-portal-control-plane.tf) via a control-plane-level implementation
# reference, rather than a specific Gateway Service. This is what makes
# ACE's operations router (see kong/plugins/ace/operations_router.lua in
# the gateway source) actually resolve `ace_operations` for a given api_id
# - without this link, incoming requests never match an operation and
# (with match_policy = "if_present") bypass ACE's auth/permission checks
# entirely.
resource "konnect_api_implementation" "implementation" {
  for_each = local.apis

  api_id = konnect_api.api[each.key].id
  control_plane_reference = {
    control_plane = {
      id = konnect_gateway_control_plane.dev_portal_cp.id
    }
  }

  depends_on = [konnect_gateway_plugin_ace.plugin_ace]
}
