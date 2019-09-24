resource "rancher2_bootstrap" "admin" {
  depends_on = [
    "google_compute_firewall.allow-web-from-anywhere-to-rancher-proxy",
    "google_compute_instance.rancher-web",
    "google_compute_instance.rancher-proxy",
    "null_resource.update-dns-proxy",
    "google_compute_firewall.allow-internal"
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

resource "null_resource" "install-kubeconfig-locally" {
  depends_on = [
    "rancher2_cluster.red"
  ]

  provisioner "local-exec" {
    command = "echo '${rancher2_cluster.red.kube_config}' | tee ~/.kube/config"
  }
}
