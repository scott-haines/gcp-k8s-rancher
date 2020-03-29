resource "google_service_account" "dev-gke-service-account" {
  account_id   = "dev-gke-service-account"
  display_name = "dev gke service account"
}

resource "google_service_account_key" "dev-gke-service-account-key" {
  service_account_id = google_service_account.dev-gke-service-account.account_id
}

resource "google_project_iam_member" "dev-gke-service-account-roles" {
  for_each = toset([
    "roles/compute.viewer",
    "roles/viewer",
    "roles/container.admin",
    "roles/iam.serviceAccountUser"
  ])
  role   = each.value
  member = "serviceAccount:${google_service_account.dev-gke-service-account.email}"
}

resource "rancher2_cluster" "dev" {
  depends_on = [
    rancher2_bootstrap.admin,
    google_project_iam_member.dev-gke-service-account-roles
  ]

  name        = "dev"
  description = "dev-cluster"
  gke_config {
    cluster_ipv4_cidr                       = ""
    credential                              = base64decode(google_service_account_key.dev-gke-service-account-key.private_key)
    disk_type                               = "pd-standard"
    enable_alpha_feature                    = false
    image_type                              = "UBUNTU"
    ip_policy_cluster_ipv4_cidr_block       = ""
    ip_policy_cluster_secondary_range_name  = ""
    ip_policy_create_subnetwork             = true
    ip_policy_node_ipv4_cidr_block          = ""
    ip_policy_services_ipv4_cidr_block      = ""
    ip_policy_services_secondary_range_name = ""
    ip_policy_subnetwork_name               = ""
    issue_client_certificate                = true
    machine_type                            = "n1-standard-1"
    maintenance_window                      = ""
    master_ipv4_cidr_block                  = ""
    master_version                          = "1.14.10-gke.24"
    network                                 = google_compute_network.vpc.name
    node_count                              = 1
    node_pool                               = ""
    node_version                            = ""
    project_id                              = var.PROJECT_ID
    service_account                         = google_service_account.dev-gke-service-account.unique_id
    sub_network                             = google_compute_subnetwork.vpc-subnet.name
    zone                                    = var.ZONE
    locations = toset([
      var.ZONE
    ])
    oauth_scopes = toset([
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ])
  }
}

resource "null_resource" "install-kubeconfig-locally" {
  depends_on = [
    rancher2_cluster.dev
  ]

  provisioner "local-exec" {
    command = "echo '${rancher2_cluster.dev.kube_config}' | tee ~/.kube/config"
  }
}