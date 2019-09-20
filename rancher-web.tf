resource "google_compute_instance" "rancher-web" {
  name         = "rancher-vm"
  machine_type = "f1-micro"
  tags         = ["rancher-web"]

  depends_on = [
    "google_compute_instance.rancher-proxy"
  ]

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
  }

  connection {
    type        = "ssh"
    user        = "${var.ssh-username}"
    agent       = "false"
    private_key = "${file("${var.ssh-private-key}")}"
    host        = "${google_compute_instance.rancher-web.network_interface.0.network_ip}"

    bastion_host        = "${google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip}"
    bastion_private_key = "${file("${var.ssh-private-key}")}"
  }

  provisioner "file" {
    source      = "config/apt-proxy.conf"
    destination = "~/apt-proxy.conf"
  }

  provisioner "file" {
    source      = "config/docker-proxy.conf"
    destination = "~/docker-proxy.conf"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
      sudo mv apt-proxy.conf /etc/apt/apt.conf.d/proxy.conf
      sudo apt update
      sudo apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg2 \
        jq \
        software-properties-common

      HTTPS_PROXY="http://rancher-proxy-vm:3128" curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
      sudo add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/debian \
        $(lsb_release -cs) \
        stable"

      sudo apt update
      sudo apt install -y docker-ce docker-ce-cli containerd.io

      sudo mkdir -p /etc/systemd/system/docker.service.d
      sudo mv docker-proxy.conf /etc/systemd/system/docker.service.d/proxy.conf

      sudo systemctl daemon-reload
      sudo systemctl restart docker

      sudo docker run \
        -d \
        --name rancher-server \
        --restart=unless-stopped \
        -p 80:80 -p 443:443 \
        -e HTTP_PROXY="http://rancher-proxy-vm:3128" \
        -e HTTPS_PROXY="http://rancher-proxy-vm:3128" \
        -e NO_PROXY="localhost,127.0.0.1,0.0.0.0,10.0.0.0/8" \
        rancher/rancher:latest --no-cacerts
    EOF
    ]
  }

  provisioner "remote-exec" {
    # This is being executed on the *rancher-proxy* to restart nginx now that
    #  upstream has availability
    connection {
      type        = "ssh"
      user        = "${var.ssh-username}"
      agent       = "false"
      private_key = "${file("${var.ssh-private-key}")}"
      host        = "${google_compute_instance.rancher-proxy.network_interface.0.network_ip}"

      bastion_host        = "${google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip}"
      bastion_private_key = "${file("${var.ssh-private-key}")}"
    }

    inline = [
      "sudo systemctl restart nginx"
    ]
  }
}
