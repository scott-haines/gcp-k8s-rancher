resource "google_compute_instance" "rancher-proxy" {
  name         = "rancher-proxy-vm"
  machine_type = "f1-micro"
  tags         = ["rancher-proxy"]

  metadata = {
    ssh-keys = "${var.ssh-username}:${file("~/.ssh/id_rsa.pub")}"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.vpc-subnet.name}"

    access_config {
      // this section is included to give external IP
    }
  }

  connection {
    type        = "ssh"
    user        = "${var.ssh-username}"
    agent       = "false"
    private_key = "${file("${var.ssh-private-key}")}"
    host        = "${google_compute_instance.rancher-proxy.network_interface.0.network_ip}"

    bastion_host        = "${google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip}"
    bastion_private_key = "${file("${var.ssh-private-key}")}"
  }

  provisioner "file" {
    source      = "secrets/letsencrypt.tar.gz"
    destination = "~/letsencrypt.tar.gz"
  }

  provisioner "file" {
    source      = "config/nginx-template.conf"
    destination = "~/nginx-template.conf"
  }

  provisioner "file" {
    source      = "config/squid.conf"
    destination = "~/squid.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx",
      "sudo apt install -y certbot python-certbot-nginx -t stretch-backports",
      "sudo tar -xvf letsencrypt.tar.gz --directory /",
      "sudo sed -i s/RANCHER_PROXY_FQDN/${var.rancher-proxy-fqdn}/g nginx-template.conf",
      "sudo mv nginx-template.conf /etc/nginx/nginx.conf",
      "sudo apt install -y squid3",
      "sudo mv squid.conf /etc/squid/squid.conf",
      "sudo systemctl restart squid"
    ]
  }

  provisioner "local-exec" {
    command = "curl -X POST 'https://${var.dns-rancher-proxy-username}:${var.dns-rancher-proxy-password}@domains.google.com/nic/update?hostname=${var.rancher-proxy-fqdn}&myip=${google_compute_instance.rancher-proxy.network_interface.0.access_config.0.nat_ip}&offline=no'"
  }

  provisioner "local-exec" {
    when       = "destroy"
    command    = "curl -X POST 'https://${var.dns-rancher-proxy-username}:${var.dns-rancher-proxy-password}@domains.google.com/nic/update?hostname=${var.rancher-proxy-fqdn}&offline=yes'"
    on_failure = "continue"
  }
}
