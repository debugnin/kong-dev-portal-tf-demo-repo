resource "konnect_gateway_control_plane" "dev_portal_cp" {
  name         = var.dev_portal_cp_name
  description  = "Control plane for Dev Portal APIs"
  cluster_type = "CLUSTER_TYPE_HYBRID"
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
