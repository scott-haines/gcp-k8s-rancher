resource "google_compute_instance" "red-nodes" {
  count        = "${var.red-node-count}"
  name         = "red-node-vm-${count.index}"
  machine_type = "n1-standard-1"
  tags         = ["red-nodes"]

  depends_on = [
    "google_compute_instance.bastion"
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

    access_config {
      // this section is included to give external IP
    }
  }
}

resource "null_resource" "install-red-nodes" {
  count = "${var.red-node-count}"

  depends_on = [
    "google_compute_instance.red-nodes"
  ]

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
      sudo modprobe br_netfilter
      sudo echo ${google_compute_instance.rancher-proxy.network_interface.0.network_ip} ${var.rancher-proxy-fqdn} | sudo tee -a /etc/hosts
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

resource "null_resource" "register-red-nodes" {
  count = "${var.red-node-count}"

  depends_on = [
    "null_resource.install-red-nodes",
    "rancher2_cluster.red"
  ]

  connection {
    type        = "ssh"
    user        = "${var.ssh-username}"
    agent       = "false"
    private_key = "${file("${var.ssh-private-key}")}"
    host        = "${element(google_compute_instance.red-nodes.*.network_interface.0.network_ip, count.index)}"

    bastion_host        = "${google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip}"
    bastion_private_key = "${file("${var.ssh-private-key}")}"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
    ${rancher2_cluster.red.cluster_registration_token.0.node_command} \
        --worker --etcd --controlplane
    EOF
    ]
  }
}

resource "null_resource" "update-dns-red" {
  # only run this once and point DNS to the first red node
  #  not ideal - but works.

  depends_on = [
    "null_resource.register-red-nodes"
  ]

  provisioner "local-exec" {
    command = "curl -X POST 'https://${var.dns-ingress-username}:${var.dns-ingress-password}@domains.google.com/nic/update?hostname=${var.ingress-fqdn}&myip=${google_compute_instance.red-nodes.0.network_interface.0.access_config.0.nat_ip}&offline=no'"
  }

  provisioner "local-exec" {
    when       = "destroy"
    command    = "curl -X POST 'https://${var.dns-ingress-username}:${var.dns-ingress-password}@domains.google.com/nic/update?hostname=${var.ingress-fqdn}&offline=yes'"
    on_failure = "continue"
  }
}

resource "null_resource" "mount-persistent-filesystem" {
  count = "${var.red-node-count}"

  depends_on = [
    "google_compute_instance.red-nodes",
    "rancher2_cluster.red",
    "google_compute_instance.fs-nfs"
  ]

  connection {
    type        = "ssh"
    user        = "${var.ssh-username}"
    agent       = "false"
    private_key = "${file("${var.ssh-private-key}")}"
    host        = "${element(google_compute_instance.red-nodes.*.network_interface.0.network_ip, count.index)}"

    bastion_host        = "${google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip}"
    bastion_private_key = "${file("${var.ssh-private-key}")}"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
      sudo apt install -y \
        nfs-common

      sudo mkdir /persistent-storage
      sudo mount nfs-vm:/mnt/disks/persistent-storage /persistent-storage
    EOF
    ]
  }
}
