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

# OIDC
variable "dev_portal_oidc_issuer" {
  description = "OIDC issuer URL"
  type        = string
  default     = ""
}

variable "dev_portal_oidc_client_id" {
  description = "OIDC client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dev_portal_oidc_client_secret" {
  description = "OIDC client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dev_portal_oidc_scopes" {
  description = "OIDC scopes"
  type        = list(string)
  default     = ["openid", "profile", "email"]
}

variable "dev_portal_oidc_claim_name" {
  description = "OIDC claim mapping for user name"
  type        = string
  default     = "name"
}

variable "dev_portal_oidc_claim_email" {
  description = "OIDC claim mapping for user email"
  type        = string
  default     = "email"
}

variable "dev_portal_oidc_claim_groups" {
  description = "OIDC claim mapping for user groups"
  type        = string
  default     = "group"
}

# Application Auth Strategy (M2M API consumers)
variable "app_auth_oidc_issuer" {
  description = "OIDC issuer for the M2M application auth strategy"
  type        = string
  default     = ""
}

variable "app_auth_oidc_scopes" {
  description = "OIDC scopes for the M2M application auth strategy"
  type        = list(string)
  default     = []
}

variable "app_auth_oidc_audience" {
  description = "OIDC audience (API identifier) for the M2M application auth strategy"
  type        = string
  default     = ""
}

variable "app_auth_dcr_client_id" {
  description = "Client ID of the Auth0 Machine-to-Machine application used for Dynamic Client Registration"
  type        = string
  sensitive   = true
  default     = ""
}

variable "app_auth_dcr_client_secret" {
  description = "Client secret of the Auth0 Machine-to-Machine application used for Dynamic Client Registration"
  type        = string
  sensitive   = true
  default     = ""
}
