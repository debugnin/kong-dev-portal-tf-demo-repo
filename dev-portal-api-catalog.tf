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
      file("${path.module}/api-specs/${local.api_files[each.key].path}"),
      "/servers:\\s*-\\s*url:\\s*\"[^\"]*\"/",
      ""
    ),
    "paths:",
    "servers:\n  - url: \"${var.dataplane_api_base_url}\"\npaths:"
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
    file("${path.module}/api-specs/${dirname(local.api_files[each.key].path)}/additional-doc.md"),
    "__DATAPLANE_BASE_URL__",
    var.dataplane_api_base_url
  )
  slug = "${each.key}-docs"
  status  = "published"
  title   = "${local.api_specs[each.key].info.title} API Documentation"
}

# Application Auth Strategy - API key auth. Developers register an
# application in the Dev Portal and are issued an API key directly (no
# external identity provider / DCR involved) that they send on the
# "apikey" header on every request.
resource "konnect_application_auth_strategy" "api_key" {
  key_auth = {
    name          = "api-key"
    display_name  = "API Key"
    strategy_type = "key_auth"
    configs = {
      key_auth = {
        key_names = ["apikey"]
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
  # Private APIs require an API key issued through the Dev Portal.
  auth_strategy_ids = local.api_files[each.key].visibility == "public" ? null : [konnect_application_auth_strategy.api_key.id]
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
