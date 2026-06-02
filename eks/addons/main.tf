locals {
  region            = var.region
  oidc_provider_url = replace(var.oidc_provider_url, "https://", "")
}
