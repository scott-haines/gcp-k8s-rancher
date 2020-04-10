# Rancher with GCP

# Purpose
This package uses Terraform to create and provision Rancher on GCP.  It attempts to use Terraform objects wherever possible.

# Prerequisites
Older versions may work but are untested and unconfirmed.
Run `make preflight-check` to ensure versions are up to date.
1. Google Cloud SDK 251.0.0 [https://cloud.google.com/sdk/docs/quickstarts]
    * Ensure that gcloud can run locally and is configured to use your desired environment.
1. Terraform v0.12.18 [https://learn.hashicorp.com/terraform/getting-started/install.html]
1. jq jq-1.6 [https://stedolan.github.io/jq/]
1. GCP APIs enabled (run `make preflight-check` to test)
    * cloudresourcemanager.googleapis.com `gcloud services enable cloudresourcemanager.googleapis.com`
    * compute.googleapis.com `gcloud services enable compute.googleapis.com`
    * container.googleapis.com `gcloud services enable container.googleapis.com`
    * iam.googleapis.com `gcloud services enable iam.googleapis.com`

# Getting Started
1. Create a storage bucket in GCP [https://cloud.google.com/storage/docs/creating-buckets]
1. Export the following variables with their correct values:
* `export TF_VAR_PROJECT_ID=<GCP_PROJECT_ID>`
    
1. Run `make preflight-check` to check that pre-requisites are all met.
1. Run `make service-account` to generate a gcp service account & exported key which will be used for all terraform commands.
1. Run `terraform init` to initialize the terraform providers.
1. Run `terraform apply` to create all the resources.

# Cleaning Up
1. Run `terraform destroy` to remove all resources by terraform.
1. Run `make remove-service-account` to clean up the service account and delete the API token file.

# Resources
The following resources are created as part of this package

## variables.tf
All overridable variables are contained in this file.  Variables can be overridden using normal terraform methods (env vars begining with `TF_VAR_`, autovars, etc.)

## vpc.tf
### google_compute_network vpc
The primary vpc network for all created resources
### google_compute_subnetwork vpc-subnet
The sole subnet for all resources which require an internal IP address.
### google_compute_firewall allow-internal
Firewall rule to allow all internal TCP and ICMP traffic to flow.  This is for development purposes only, in a production environment internal traffic flow should be limited to only the required ports.
### google_compute_firewall allow-ssh-from-anywhere-to-bastion
Firewall rule to allow ssh (TCP 22) access to the bastion resource from any IP address.
### google_compute_firewall allow-http-https-from-anywhere-to-rancher-web
Firewall rule to allow http (TCP 80) and https (TCP 443) access to the rancher-web resource from any IP address.

## bastion.tf
### google_compute_instance bastion
Bastion server to act as a jumpbox to get access to the other resources.
#### Outputs
* bastion_public_ip - The public IP address of the bastion server.
### null_resource bastion-google-dns
An optional resource which set the public dns for the public IP of the bastion using google dns.
Should you wish to make use of the google DNS objects override the following variables using your preferred method:    
* bastion_dns_use_google_dns = true
* bastion_dns_username
* bastion_dns_password
* bastion_dns_fqdn

## rancher-web.tf
### google_compute_instance rancher-web
The server which hosts the main rancher web interface.
#### Outputs
* rancher_web_public_ip - The publicIP address of the rancher web server.
### null_resource rancher-web-google-dns
An optional resource which set the public dns for the public IP of rancher-web using google dns.
Should you wish to make use of the google DNS objects override the following variables using your preferred method:    
* rancher_web_dns_use_google_dns = true
* rancher_web_dns_username
* rancher_web_dns_password
* rancher_web_dns_fqdn
### null_resource rancher-web-nginx
Installs and configures nginx on the vm running rancher.
### rancher2_bootstrap admin
A special bootstrap provisioner version of the rancher2 provider (defined by specifying the provider) which is designed to configure the initial rancher setup (admin password prompt and opt-in checkbox normally presented via a browser).

# Cluster Definitions
By default there is a dev cluster defined in cluster-dev.tf to use as an example of provisioning a cluster.

The example provided uses an explicitly defined cluster.  An alertnative if you want to have a pool of clusters would be to variablize the configuration and leverage terraform to provision multiple clusters by using the "count" attribute.
