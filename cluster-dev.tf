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
    master_version                          = "1.15.9-gke.24"
    network                                 = google_compute_network.vpc.name
    node_count                              = 3
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

resource "null_resource" "provision-ingress-controller" {
  depends_on = [
    rancher2_cluster.dev,
    null_resource.install-kubeconfig-locally
  ]

  provisioner "local-exec" {
    command = "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.1/deploy/static/mandatory.yaml"
  }
}

resource "null_resource" "provision-load-balancer" {
  depends_on = [
    rancher2_cluster.dev,
    null_resource.provision-ingress-controller
  ]

  provisioner "local-exec" {
    command = "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.1/deploy/static/provider/cloud-generic.yaml"
  }
}

variable loadbalancer_dns_username {
  default = ""
}

variable loadbalancer_dns_password {
  default = ""
}

variable loadbalancer_dns_fqdn {
  default = ""
}

resource "null_resource" "wildcard-loadbalancer-google-dns" {
  depends_on = [
      null_resource.provision-load-balancer
  ]
  triggers = {
    username       = var.loadbalancer_dns_username
    password       = var.loadbalancer_dns_password
    fqdn           = var.loadbalancer_dns_fqdn
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOF
    curl -X POST "https://${self.triggers.username}:${self.triggers.password}@domains.google.com/nic/update?hostname=${self.triggers.fqdn}&myip=$(kubectl get svc --namespace=ingress-nginx -o=json | jq -r '.items[0].status.loadBalancer.ingress[0].ip')&offline=no"
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
    curl -X POST "https://${self.triggers.username}:${self.triggers.password}@domains.google.com/nic/update?hostname=${self.triggers.fqdn}&offline=yes"
    EOF
    on_failure = continue
  }
}

variable letsencrypt_email {
  default = ""
}

resource "null_resource" "provision-cert-manager" {
  depends_on = [
    null_resource.wildcard-loadbalancer-google-dns
  ]
  triggers = {
    staging_email_address = var.letsencrypt_email
    prod_email_address = var.letsencrypt_email
  }
  
  provisioner "local-exec" {
    when    = create
    command = <<EOT
    kubectl create namespace cert-manager
    kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.12.0/cert-manager.yaml
    
    # one-liner to wait until the webhook deployment is ready
    while [[ $(kubectl get pods --namespace=cert-manager -l app=webhook -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 20; done

    # Create staging issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
 name: letsencrypt-staging
 namespace: cert-manager
spec:
 acme:
   # The ACME server URL
   server: https://acme-staging-v02.api.letsencrypt.org/directory
   # Email address used for ACME registration
   email: ${self.triggers.staging_email_address}
   # Name of a secret used to store the ACME account private key
   privateKeySecretRef:
     name: letsencrypt-staging
   # Enable the HTTP-01 challenge provider
   solvers:
   - http01:
       ingress:
         class:  nginx
EOF

    # Create prod issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: ${self.triggers.prod_email_address}
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          class: nginx
    EOT
  }
}