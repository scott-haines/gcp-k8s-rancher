resource "google_compute_network" "vpc" {
  name = var.vpc_name

  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpc-subnet" {
  name          = var.vpc_subnet_name
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.vpc_subnet_cidr_block
}

resource "google_compute_firewall" "allow-internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    google_compute_subnetwork.vpc-subnet.ip_cidr_range
  ]
}

resource "google_compute_firewall" "allow-ssh-from-anywhere-to-bastion" {
  name    = "allow-bastion"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["bastion"]
}