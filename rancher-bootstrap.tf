resource "rancher2_bootstrap" "admin" {
  depends_on = [
    "google_compute_instance.rancher-web"
  ]

  provider  = "rancher2.bootstrap"
  password  = "${var.rancher-admin-password}"
  telemetry = false
}
