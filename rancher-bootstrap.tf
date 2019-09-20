resource "rancher2_bootstrap" "admin" {
  depends_on = [
    "google_compute_instance.rancher-web"
  ]

  provider  = "rancher2.bootstrap"
  password  = "${var.rancher-admin-password}"
  telemetry = false
}

resource "rancher2_cluster" "red" {
  name        = "red"
  description = "red cluster"
  rke_config {
    network {
      plugin = "canal"
    }
  }
}

resource "rancher2_cluster" "black" {
  name        = "black"
  description = "black cluster"
  rke_config {
    network {
      plugin = "canal"
    }
  }
}
