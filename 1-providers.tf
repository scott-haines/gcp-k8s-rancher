provider "google" {
  credentials = "${file("secrets/service-account-credentials.json")}"
  project     = "${var.project-name}"
  region      = "us-east1"
  zone        = "us-east1-b"
}
