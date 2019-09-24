provider "google" {
  credentials = "${file("secrets/service-account-credentials.json")}"
  project     = "${var.project-name}"
  region      = "us-east1"
  zone        = "us-east1-b"
}

provider "rancher2" {
  alias     = "bootstrap"
  api_url   = "https://${var.rancher-proxy-fqdn}"
  bootstrap = true
}

provider "rancher2" {
  api_url   = "${rancher2_bootstrap.admin.url}"
  token_key = "${rancher2_bootstrap.admin.token}"
}

provider "kubernetes" {}
