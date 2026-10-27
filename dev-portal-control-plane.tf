resource "konnect_gateway_control_plane" "dev_portal_cp" {
  name         = var.dev_portal_cp_name
  description  = "Control plane for Dev Portal APIs"
  cluster_type = "CLUSTER_TYPE_HYBRID"
}

# Access Control Enforcement (ACE) - enforces the auth strategy selected on
# each API's publication (see konnect_api_publication.publication) against
# this control plane, replacing the per-route openid-connect scope checks
# that scripts/deck-sync.sh used to inject manually. Scoped to the whole
# control plane rather than a single Gateway Service, per Kong's guidance
# not to mix ACE with the KAA plugin on the same control plane.
resource "konnect_gateway_plugin_ace" "plugin_ace" {
  control_plane_id = konnect_gateway_control_plane.dev_portal_cp.id
  config = {
    # Only enforce access control on requests that match a published API
    # operation; everything else (e.g. mocking echo routes) passes through
    # untouched rather than being 404'd outright.
    match_policy = "if_present"
  }
  tags = ["managed-by-terraform"]
}

resource "konnect_gateway_plugin_cors" "plugin_cors" {
  control_plane_id = konnect_gateway_control_plane.dev_portal_cp.id
  config = {
    origins            = ["*"]
    methods            = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    headers            = ["*"]
    exposed_headers    = ["*"]
    credentials        = true
    max_age            = 3600
    preflight_continue = false
  }
  tags = ["managed-by-terraform"]
}
