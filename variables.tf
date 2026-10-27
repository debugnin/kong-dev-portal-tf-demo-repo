# Provisioner control
variable "provisioner_trigger" {
  description = "Change this value to manually trigger all null_resource provisioners on the next apply"
  type        = string
  default     = "7"
}

# Auth
variable "konnect_token" {
  description = "Personal Access Token for Konnect"
  type        = string
  sensitive   = true
}

variable "konnect_api_url" {
  description = "Konnect API URL"
  type        = string
  default     = "https://au.api.konghq.com"
}

variable "organisation_name" {
  description = "The name of the organisation"
  type        = string
  default     = "KongAir"
}

# Control Plane
variable "dev_portal_cp_name" {
  description = "Name of the Konnect control plane"
  type        = string
  default     = "Dev Portal Control Plane"
}

variable "dataplane_api_base_url" {
  description = "Base URL of the Kong data plane that serves the published APIs"
  type        = string
  default     = ""
}

# Portal
variable "dev_portal_name" {
  description = "The name of the Dev Portal in Konnect"
  type        = string
  default     = "Developer Portal"
}

variable "dev_portal_display_name" {
  description = "The name of the Dev Portal displayed within the Dev Portal application"
  type        = string
  default     = "Developer Portal"
}

variable "dev_portal_desc_prefix" {
  description = "Used to assemble the Dev Portal description: '<prefix> <organisation_name> <suffix>'"
  type        = string
  default     = "Developer Portal deployed for"
}

variable "dev_portal_desc_suffix" {
  description = "Used to assemble the Dev Portal description: '<prefix> <organisation_name> <suffix>'"
  type        = string
  default     = "production use-cases."
}

# Branding
variable "dev_portal_logo_path" {
  description = "Path to the logo image for the Dev Portal"
  type        = string
  default     = "./dev-portal/image-assets/kong-air-logo.png"
}

variable "dev_portal_logo_file_type" {
  description = "Logo file type — one of 'png', 'svg', 'jpeg', 'gif'"
  type        = string
  default     = "png"
}

variable "dev_portal_brand_color" {
  description = "Primary brand color code"
  type        = string
  default     = "#8250FF"
}

variable "dev_portal_color_mode" {
  description = "Portal color mode — one of 'light', 'dark', 'system'"
  type        = string
  default     = "light"
}

# Pages & Snippets
variable "dev_portal_snippet_code_block_graphix_path" {
  description = "Path to the code-block-graphix snippet content"
  type        = string
  default     = "./dev-portal/snippets/code-block-graphix.md"
}

variable "dev_portal_page_home_path" {
  description = "Path to the home page content"
  type        = string
  default     = "./dev-portal/pages/home.md"
}

variable "dev_portal_page_getting_started_path" {
  description = "Path to the getting-started page content"
  type        = string
  default     = "./dev-portal/pages/getting-started.md"
}

variable "dev_portal_page_apis_path" {
  description = "Path to the APIs page content"
  type        = string
  default     = "./dev-portal/pages/apis.md"
}

variable "dev_portal_page_content_home_page_hero_bg_img_url" {
  description = "Background image URL for the home page hero section"
  type        = string
  default     = "https://github.com/jharmn/img-bucket/blob/main/images/travel.png?raw=true"
}

variable "dev_portal_page_content_home_page_hero_text_color" {
  description = "Text color for the home page hero section"
  type        = string
  default     = "#000000"
}

variable "dev_portal_page_content_home_page_hero_img_width" {
  description = "Background image width for the home page hero section"
  type        = string
  default     = "55%"
}

# Note: Dev Portal login previously supported OIDC/SSO, and the
# application auth strategy previously used Auth0 OIDC via Dynamic Client
# Registration (DCR). Both have been replaced with simpler alternatives:
# the portal now only supports basic-auth login (konnect_portal_auth in
# dev-portal-setup.tf), and applications authenticate via a Konnect-issued
# API key (konnect_application_auth_strategy.api_key in
# dev-portal-api-catalog.tf) — no external identity provider is required.
