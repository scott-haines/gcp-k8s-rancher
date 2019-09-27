resource "rancher2_project" "cert-manager" {
  depends_on = [
    "google_compute_instance.red-nodes",
    "rancher2_bootstrap.admin",
    "rancher2_cluster.red",
    "null_resource.update-dns-proxy"
  ]

  name             = "cert-manager"
  cluster_id       = "${rancher2_cluster.red.id}"
  wait_for_cluster = true
}

resource "rancher2_namespace" "cert-manager" {
  depends_on = [
    "rancher2_project.cert-manager"
  ]

  name        = "cert-manager"
  project_id  = "${rancher2_project.cert-manager.id}"
  description = "Namespace for the cert-manager app"
}

resource "rancher2_app" "cert-manager" {
  depends_on = [
    "rancher2_namespace.cert-manager"
  ]
  catalog_name     = "library"
  template_name    = "cert-manager"
  template_version = "v0.5.2"

  name             = "cert-manager"
  description      = "Automatically manages certificates for cluster."
  project_id       = "${rancher2_project.cert-manager.id}"
  target_namespace = "${rancher2_namespace.cert-manager.name}"
  answers = {
    "defaultImage"                  = true
    "image.repository"              = "quay.io/jetstack/cert-manager-controller"
    "image.tag"                     = "v0.5.2"
    "webhook.image.repository"      = "quay.io/jetstack/cert-manager-webhook"
    "webhook.image.tag"             = "v0.5.2"
    "replicaCount"                  = 1
    "clusterissuerEnabled"          = true
    "ingressShim.defaultIssuerName" = "letsencrypt-prod"
    "letsencrypt.name"              = "letsencrypt-prod"
    "letsencrypt.email"             = "${var.cert-manager-email}"
    "createCustomResource"          = true
    "webhook.enabled"               = false
  }
}
