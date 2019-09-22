resource "rancher2_bootstrap" "admin" {
  depends_on = [
    "google_compute_firewall.allow-web-from-anywhere-to-rancher-proxy",
    "google_compute_instance.rancher-web",
    "google_compute_instance.rancher-proxy",
    "null_resource.update-dns-proxy"
  ]

  provider  = "rancher2.bootstrap"
  password  = "${var.rancher-admin-password}"
  telemetry = false
}

resource "rancher2_cluster" "red" {
  depends_on = [
    "rancher2_bootstrap.admin",
    "google_compute_firewall.allow-web-from-anywhere-to-rancher-proxy",
    "google_compute_instance.rancher-web",
    "google_compute_instance.rancher-proxy",
    "null_resource.update-dns-proxy"
  ]

  name        = "red"
  description = "red cluster"
  rke_config {
    network {
      plugin = "canal"
    }
  }
}

output "kube_config" {
  value = "${rancher2_cluster.red.kube_config}"
}
