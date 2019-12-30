resource "google_compute_instance" "rancher-web" {
  name         = var.rancher_web_name
  machine_type = var.rancher_web_size
  tags         = ["rancher-web"]

  metadata = {
    ssh-keys = "${var.bastion_username}:${file("~/.ssh/id_rsa.pub")}"
  }

  boot_disk {
    initialize_params {
      image = var.rancher_web_image
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
    user        = var.bastion_username
    agent       = false
    private_key = file("~/.ssh/id_rsa")
    host        = google_compute_instance.rancher-web.network_interface.0.network_ip

    bastion_host        = google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip
    bastion_private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [<<EOF
      sudo apt update
      sudo apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg2 \
        software-properties-common
      curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
      sudo add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/debian \
        $(lsb_release -cs) \
        stable"
      sudo apt update
      sudo apt install -y docker-ce docker-ce-cli containerd.io
      sudo docker run \
        -d \
        --name rancher-server \
        --restart=unless-stopped \
        -p 80:80 -p 443:443 \
        rancher/rancher:latest --no-cacerts

      # don't consider provisioning complete until ping pong
      while ! curl -k https://localhost/ping; do sleep 8; done
    EOF
    ]
  }
}

output "rancher_web_public_ip" {
  value = google_compute_instance.rancher-web.network_interface.0.access_config.0.nat_ip
}

resource "null_resource" "rancher-web-google-dns" {
  count = var.rancher_web_dns_use_google_dns ? 1 : 0

  # By storing state within the triggers this ensures that the destroy-time provisioner will have
  #  access to the needed variables.  It will also ensure that recreation will happen correctly
  #  should changes occurr which require recreation.
  # This *may* cause issues if the username or password were to change as the state will still contain
  #  the old, original username & password and it won't be able to successfully connect to googles 
  #  dns api as the credentials being used are stale.
  triggers = {
    rancher_web_nat_ip = google_compute_instance.rancher-web.network_interface.0.access_config.0.nat_ip,
    username       = var.rancher_web_dns_username
    password       = var.rancher_web_dns_password
    fqdn           = var.rancher_web_dns_fqdn
  }

  provisioner "local-exec" {
    when    = create
    command = "curl -X POST 'https://${self.triggers.username}:${self.triggers.password}@domains.google.com/nic/update?hostname=${self.triggers.fqdn}&myip=${self.triggers.rancher_web_nat_ip}&offline=no'"
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "curl -X POST 'https://${self.triggers.username}:${self.triggers.password}@domains.google.com/nic/update?hostname=${self.triggers.fqdn}&offline=yes'"
    on_failure = continue
  }
}