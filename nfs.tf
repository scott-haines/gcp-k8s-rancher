resource "google_compute_instance" "fs-nfs" {
  name         = "nfs-vm"
  machine_type = "f1-micro"
  tags         = ["fs-nfs"]

  metadata = {
    ssh-keys = "${var.ssh-username}:${file("~/.ssh/id_rsa.pub")}"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  attached_disk {
    source = "persistent-storage" # Expected to already exist
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.vpc-subnet.name}"
  }

  connection {
    type        = "ssh"
    user        = "${var.ssh-username}"
    agent       = "false"
    private_key = "${file("${var.ssh-private-key}")}"
    host        = "${google_compute_instance.fs-nfs.network_interface.0.network_ip}"

    bastion_host        = "${google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip}"
    bastion_private_key = "${file("${var.ssh-private-key}")}"
  }

  provisioner "file" {
    source      = "config/apt-proxy.conf"
    destination = "~/apt-proxy.conf"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
      sudo mv apt-proxy.conf /etc/apt/apt.conf.d/proxy.conf
      sudo apt update
      sudo apt install -y \
        nfs-common \
        nfs-kernel-server \
        nfs-common
      sudo mkdir -p /mnt/disks/persistent-storage
      sudo mount -o discard,defaults /dev/sdb /mnt/disks/persistent-storage
      sudo chmod a+w /mnt/disks/persistent-storage

      sudo cp /etc/fstab /etc/fstab.backup
      echo UUID=`sudo blkid -s UUID -o value /dev/sdb` /mnt/disks/disk-1 ext4 discard,defaults,nofail 0 2 | sudo tee -a /etc/fstab

      echo "/mnt/disks/persistent-storage *(rw,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports
      sudo systemctl restart nfs-kernel-server
    EOF
    ]
  }
}

resource "kubernetes_storage_class" "persistent-storage" {
  depends_on = [
    "null_resource.install-kubeconfig-locally"
  ]

  metadata {
    name = "persistent-storage"
  }

  storage_provisioner = "kubernetes.io/no-provisioner"
  reclaim_policy      = "Retain"
}
