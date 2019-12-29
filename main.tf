terraform {
  # using an in-memory backend
}

provider "google" {
  credentials = file("secrets/gcp-k8s-rancher-key.json")
  project     = var.PROJECT_ID
  region      = var.REGION
  zone        = var.ZONE
}

provider "rancher2" {
  alias     = "bootstrap"
  api_url   = "https://${var.rancher-proxy-fqdn}"
  bootstrap = true
}

provider "rancher2" {
  api_url   = rancher2_bootstrap.admin.url
  token_key = rancher2_bootstrap.admin.token
}

provider "kubernetes" {}
