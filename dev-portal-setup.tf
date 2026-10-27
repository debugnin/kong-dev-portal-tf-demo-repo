# Create Dev Portal
resource "konnect_portal" "dev_portal" {
  name                                 = var.dev_portal_name
  authentication_enabled               = true
  auto_approve_applications            = true
  auto_approve_developers              = true
  rbac_enabled                         = true
  default_api_visibility               = "private"
  default_page_visibility              = "private"
  description                          = "${var.dev_portal_desc_prefix} ${var.organisation_name} ${var.dev_portal_desc_suffix}"
  display_name                         = var.dev_portal_display_name
  force_destroy                        = "true"
  # Without this, the Create Application page in the portal has no
  # preselected auth strategy, which was a contributing factor in a
  # frontend exception (Cloudflare error 1101) when submitting the form.
  default_application_auth_strategy_id = konnect_application_auth_strategy.api_key.id
}

# Customization of Portal
## Logo
resource "konnect_portal_logo" "dev_portal_logo" {
  data      = "data:image/${var.dev_portal_logo_file_type};base64,${filebase64(var.dev_portal_logo_path)}"
  portal_id = konnect_portal.dev_portal.id
}

# Create Snippets
resource "konnect_portal_snippet" "code_block_graphix" {
  name        = "code-block-graphix"
  content     = file(var.dev_portal_snippet_code_block_graphix_path)
  description = "A header/footer graphic than can be re-used on multiple pages."
  title       = "code-block-graphix"
  status      = "published"
  visibility  = "public"
  portal_id   = konnect_portal.dev_portal.id
}

resource "konnect_portal_page" "getting-started" {
  content     = file(var.dev_portal_page_getting_started_path)
  description = "Get started with our Developer Portal!"
  title       = "getting-started"
  status      = "published"
  visibility  = "public"
  slug        = "/getting-started"
  portal_id   = konnect_portal.dev_portal.id
}

resource "konnect_portal_page" "home" {
  content = templatefile(var.dev_portal_page_home_path, {
    organisation_name                                 = var.organisation_name
    dev_portal_page_content_home_page_hero_bg_img_url = var.dev_portal_page_content_home_page_hero_bg_img_url
    dev_portal_page_content_home_page_hero_text_color = var.dev_portal_page_content_home_page_hero_text_color
    dev_portal_page_content_home_page_hero_img_width  = var.dev_portal_page_content_home_page_hero_img_width
  })
  description = "Start building and innovating with our APIs"
  title       = "home"
  status      = "published"
  visibility  = "public"
  slug        = "/"
  portal_id   = konnect_portal.dev_portal.id
}

resource "konnect_portal_page" "apis" {
  content     = file(var.dev_portal_page_apis_path)
  description = "Explore a wide range of API products in our Developer Portal designed for fast, flexible development."
  title       = "apis"
  status      = "published"
  visibility  = "private"
  slug        = "/apis"
  portal_id   = konnect_portal.dev_portal.id
}

# Create Customizations
resource "konnect_portal_customization" "dev_portal" {
  menu = {
    main = [
      {
        external   = false
        path       = "/"
        title      = "Home"
        visibility = "public"
      },
      {
        external   = false
        path       = "/getting-started"
        title      = "Getting Started"
        visibility = "public"
      },
      {
        external   = false
        path       = "/apis"
        title      = "API Catalog"
        visibility = "public"
      },
    ]
    footer_bottom = []
    footer_sections = [
      {
        title = "Products"
        items = [
          {
            external   = false
            path       = "#"
            title      = "Pricing"
            visibility = "public"
          },
          {
            external   = false
            path       = "/apis"
            title      = "APIs"
            visibility = "public"
          },
          {
            external   = false
            path       = "#"
            title      = "Documentation"
            visibility = "public"
          }
        ]
      },
      {
        title = "Company"
        items = [
          {
            external   = false
            path       = "#"
            title      = "About"
            visibility = "public"
          },
          {
            external   = false
            path       = "#"
            title      = "Careers"
            visibility = "public"
          },
          {
            external   = false
            path       = "#"
            title      = "Press"
            visibility = "public"
          },
          {
            external   = false
            path       = "#"
            title      = "Events"
            visibility = "public"
          },
          {
            external   = false
            path       = "#"
            title      = "Investors"
            visibility = "public"
          }
        ]
      },
      {
        title = "Legal"
        items = [
          {
            external   = false
            path       = "#"
            title      = "Terms and conditions"
            visibility = "public"
          },
          {
            external   = false
            path       = "#"
            title      = "Data privacy"
            visibility = "public"
          },
          {
            external   = false
            path       = "#"
            title      = "Trust and compliance"
            visibility = "public"
          }
        ]
      }
    ]
  }
  theme = {
    colors = {
      primary = "${var.dev_portal_brand_color}"
    }
    mode = "${var.dev_portal_color_mode}"
  }
  portal_id = konnect_portal.dev_portal.id
}

# Teams
locals {
  api_teams = {
    for pair in setproduct(tolist(local.apis), ["read", "write"]) :
    "${pair[0]}-${pair[1]}" => {
      api    = pair[0]
      access = pair[1]
    }
  }
}

## Portal Admin
resource "konnect_portal_team" "portal-admin" {
  description = "Portal administrators with full access to the developer portal."
  name        = "portal-admin"
  portal_id   = konnect_portal.dev_portal.id
}

## Per-API read/write teams
resource "konnect_portal_team" "api_team" {
  for_each = local.api_teams

  name        = each.key
  description = "${title(each.value.access)} access to the ${local.api_specs[each.value.api].info.title} API."
  portal_id   = konnect_portal.dev_portal.id
}

## Portal Admin role assignment
## NOTE: kept as local-exec — konnect_portal_team_role (provider 3.22.0) has
## no import support, so these already-assigned roles can't be adopted into
## Terraform state without deleting and recreating them live. Revisit once
## the provider adds import support for this resource.
resource "null_resource" "portal-team-portal-admin-role" {
  triggers = {
    always_run = var.provisioner_trigger
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
      set -e
      RESP_FILE=$(mktemp)
      trap 'rm -f "$RESP_FILE"' EXIT

      HTTP_STATUS=$(curl -s -o "$RESP_FILE" -w "%%{http_code}" --request POST \
        --url "${var.konnect_api_url}/v3/portals/${konnect_portal.dev_portal.id}/teams/${konnect_portal_team.portal-admin.id}/assigned-roles" \
        --header 'Accept: application/json, application/problem+json' \
        --header "Authorization: Bearer $KONNECT_TOKEN" \
        --header 'Content-Type: application/json' \
        --data '{
          "role_name": "API Consumer",
          "entity_id": "*",
          "entity_type_name": "Services",
          "entity_region": "au"
        }')
      # 409 means the role is already assigned — treat as success so re-runs are idempotent.
      if [ "$HTTP_STATUS" -ge 400 ] && [ "$HTTP_STATUS" -ne 409 ]; then
        echo "ERROR: assigning portal admin role returned $HTTP_STATUS:" >&2
        cat "$RESP_FILE" >&2
        exit 1
      fi
    EOT
  }

  depends_on = [konnect_portal_team.portal-admin]
}

## Per-API team role assignments
## Each API team gets full read + write access to its linked API:
## "API Viewer" (read API docs) and "API Consumer" (register apps / make calls).
## NOTE: kept as local-exec — see note above on konnect_portal_team_role.
resource "null_resource" "api_team_role" {
  for_each = local.api_teams

  triggers = {
    always_run = var.provisioner_trigger
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
      set -e
      RESP_FILE=$(mktemp)
      trap 'rm -f "$RESP_FILE"' EXIT

      for ROLE in "API Viewer" "API Consumer"; do
        echo "Assigning '$ROLE' to team ${konnect_portal_team.api_team[each.key].id} on API ${konnect_api.api[each.value.api].id}..."
        HTTP_STATUS=$(curl -s -o "$RESP_FILE" -w "%%{http_code}" --request POST \
          --url "${var.konnect_api_url}/v3/portals/${konnect_portal.dev_portal.id}/teams/${konnect_portal_team.api_team[each.key].id}/assigned-roles" \
          --header 'Accept: application/json, application/problem+json' \
          --header "Authorization: Bearer $KONNECT_TOKEN" \
          --header 'Content-Type: application/json' \
          --data "{
            \"role_name\": \"$ROLE\",
            \"entity_id\": \"${konnect_api.api[each.value.api].id}\",
            \"entity_type_name\": \"Services\",
            \"entity_region\": \"au\"
          }")
        # 409 means the role is already assigned — treat as success so re-runs are idempotent.
        if [ "$HTTP_STATUS" -ge 400 ] && [ "$HTTP_STATUS" -ne 409 ]; then
          echo "ERROR: assigning '$ROLE' returned $HTTP_STATUS:" >&2
          cat "$RESP_FILE" >&2
          exit 1
        fi
      done
    EOT
  }

  depends_on = [konnect_portal_team.api_team]
}

# Dev Portal login - basic auth only. No SSO/OIDC identity provider is
# configured; teams are assigned directly via konnect_mapping_enabled
# (Konnect Identity Admin assigns teams to a developer) rather than IdP
# group mapping.
resource "konnect_portal_auth" "dev_portal" {
  portal_id               = konnect_portal.dev_portal.id
  basic_auth_enabled      = true
  idp_mapping_enabled     = false
  konnect_mapping_enabled = true

  # The API always mirrors these deprecated fields from the (now absent)
  # konnect_portal_identity_provider config, ignoring writes — they can
  # never converge to the null we intentionally leave them at.
  lifecycle {
    ignore_changes = [
      oidc_auth_enabled,
      oidc_claim_mappings,
      oidc_client_id,
      oidc_issuer,
      oidc_scopes,
      oidc_team_mapping_enabled,
      saml_auth_enabled,
    ]
  }
}
