resource "google_compute_instance" "bastion" {
  name         = var.bastion.name
  machine_type = var.bastion.size
  tags         = ["bastion"]

  metadata = {
    ssh-keys = "${var.bastion.username}:${file("~/.ssh/id_rsa.pub")}"
  }

  boot_disk {
    initialize_params {
      image = var.bastion.image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc-subnet.name

    access_config {
      // this section is included to give external IP
    }
  }

  connection {
    type        = "ssh"
    user        = var.ssh-username
    agent       = "false"
    private_key = file("~/.ssh/id_rsa")
    host        = google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip
  }
}

output "bastion_public_ip" {
  value = google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip
}

resource "null_resource" "bastion-google-dns" {
  count = var.bastion.dns.use_google_dns ? 1 : 0

  # By storing state within the triggers this ensures that the destroy-time provisioner will have
  #  access to the needed variables.  It will also ensure that recreation will happen correctly
  #  should changes occurr which require recreation.
  # This *may* cause issues if the username or password were to change as the state will still contain
  #  the old, original username & password and it won't be able to successfully connect to googles 
  #  dns api as the credentials being used are stale.
  triggers = {
    bastion_nat_ip = google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip,
    username       = var.bastion.dns.username
    password       = var.bastion.dns.password
    fqdn           = var.bastion.dns.fqdn
  }

  provisioner "local-exec" {
    when    = create
    command = "curl -X POST 'https://${self.triggers.username}:${var.bastion.dns.password}@domains.google.com/nic/update?hostname=${self.triggers.fqdn}&myip=${self.triggers.bastion_nat_ip}&offline=no'"
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "curl -X POST 'https://${self.triggers.username}:${self.triggers.password}@domains.google.com/nic/update?hostname=${self.triggers.fqdn}&offline=yes'"
    on_failure = continue
  }
}
