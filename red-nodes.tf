resource "google_compute_instance" "red-nodes" {
  count        = 1
  name         = "red-node-vm-${count.index}"
  machine_type = "f1-micro"
  tags         = ["red-nodes"]

  depends_on = [
    "rancher2_cluster.red"
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
    host        = "${element(google_compute_instance.red-nodes.*.network_interface.0.network_ip, count.index)}"

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
    EOF
    ]
  }
}
