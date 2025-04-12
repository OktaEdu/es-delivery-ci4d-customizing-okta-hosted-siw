variable "okta_private_key_pem_path" {
  description = "Path to your PEM-formatted private key file"
}

variable "okta_oauth2_client_id" {
  description = "OAuth2 client ID from your Okta OAuth Service App"
}


provider "okta" {
  org_name  = var.okta_org_name
  base_url  = var.okta_base_url
  oauth2 {
    private_key          = file(var.okta_private_key_pem_path)
    client_id            = var.okta_oauth2_client_id
    scopes               = ["okta.apps.read", "okta.apps.manage", "okta.users.manage", "okta.groups.manage", "okta.policies.manage"]
    token_url            = "https://${var.okta_org_name}.${var.okta_base_url}/oauth2/v1/token"
  }
}

variable "okta_org_name" {}
variable "okta_base_url" {
  default = "okta.com"
}
variable "okta_api_token" {}
variable "codespace_name" {}

############################
# Groups
############################
resource "okta_group" "customers" {
  name = "Customers"
}

resource "okta_group" "franchisees" {
  name = "Franchisees"
}

############################
# Group Rule for Customers
############################
resource "okta_group_rule" "add_to_customers" {
  name        = "add to group"
  status      = "ACTIVE"
  group_id    = okta_group.customers.id

  conditions {
    expression_type = "urn:okta:expression:1.0"
    expression      = "user.userType == \"customer\""
  }
}

############################
# Users
############################
resource "okta_user" "soraya" {
  first_name       = "Soraya"
  last_name        = "Esfeh"
  login            = "soraya.esfeh@oktaice.com"
  email            = "soraya.esfeh@oktaice.com"
  user_type        = "customer"
  group_memberships = [okta_group.customers.id]
  status           = "ACTIVE"
}

resource "okta_user" "kay" {
  first_name       = "Kay"
  last_name        = "West"
  login            = "kay.west@oktaice.com"
  email            = "kay.west@oktaice.com"
  group_memberships = [okta_group.franchisees.id]
  status           = "ACTIVE"
}

############################
# Trusted Origin
############################
resource "okta_trusted_origin" "codespace_origin" {
  name          = "Codespace Trusted Origin"
  origin        = "https://${var.codespace_name}-8080.app.github.dev"
  scopes        = ["CORS"]
  status        = "ACTIVE"
}

############################
# OIDC Application: Customer Rewards
############################
resource "okta_app_oauth" "customer_rewards" {
  label                      = "Customer Rewards"
  type                       = "browser"
  grant_types                = ["authorization_code", "implicit"]
  response_types             = ["token", "id_token", "code"]
  redirect_uris              = ["https://${var.codespace_name}-8080.app.github.dev/redirect/rewards.html"]
  post_logout_redirect_uris = ["https://${var.codespace_name}-8080.app.github.dev"]
  token_endpoint_auth_method = "none"
  groups_claim               = "groups"

  groups {
    filter_type = "INCLUDE"
    include     = [okta_group.customers.id]
  }
}

############################
# OIDC Application: Franchisee CRM
############################
resource "okta_app_oauth" "franchisee_crm" {
  label                      = "Franchisee CRM"
  type                       = "browser"
  grant_types                = ["authorization_code", "implicit"]
  response_types             = ["token", "id_token", "code"]
  redirect_uris              = ["https://${var.codespace_name}-8080.app.github.dev/redirect/crm.html"]
  post_logout_redirect_uris = ["https://${var.codespace_name}-8080.app.github.dev"]
  token_endpoint_auth_method = "none"
  groups_claim               = "groups"

  groups {
    filter_type = "INCLUDE"
    include     = [okta_group.franchisees.id]
  }
}

############################
# Access Policy
############################
resource "okta_auth_server_policy" "default_policy" {
  name           = "Default Policy"
  description    = "Policy for all clients"
  status         = "ACTIVE"
  auth_server_id = "default"
}

resource "okta_auth_server_policy_rule" "default_rule" {
  name            = "Default Rule"
  policy_id       = okta_auth_server_policy.default_policy.id
  auth_server_id  = "default"
  priority        = 1
  status          = "ACTIVE"
  grant_type_whitelist = ["authorization_code", "implicit", "refresh_token", "password", "client_credentials"]
  user_condition {
    users = ["ALL"]
  }
  client_condition {
    include = ["ALL_CLIENTS"]
  }
}
