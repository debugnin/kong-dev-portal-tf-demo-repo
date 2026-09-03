output "control_plane_name" {
  description = "Name of the Konnect control plane"
  value       = konnect_gateway_control_plane.dev_portal_cp.name
}

output "dataplane_url" {
  description = "Data plane base URL"
  value       = var.dataplane_api_base_url
}
