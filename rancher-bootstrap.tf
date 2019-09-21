resource "null_resource" "wait-for-rancher" {
  provisioner "local-exec" {
    command = "while ! curl -k https://${var.rancher-proxy-fqdn}/ping; do sleep 8; done"
  }
}

resource "rancher2_bootstrap" "admin" {
  depends_on = [
    "null_resource.wait-form-rancher"
  ]

  provider  = "rancher2.bootstrap"
  password  = "${var.rancher-admin-password}"
  telemetry = false
}

resource "rancher2_cluster" "red" {
  depends_on = [
    "rancher2_bootstrap.admin"
  ]

  name        = "red"
  description = "red cluster"
  rke_config {
    network {
      plugin = "canal"
    }
  }
}

resource "rancher2_cluster" "black" {
  depends_on = [
    "rancher2_bootstrap.admin"
  ]

  name        = "black"
  description = "black cluster"
  rke_config {
    network {
      plugin = "canal"
    }
  }
}
