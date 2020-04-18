[![Gitpod Ready-to-Code](https://img.shields.io/badge/Gitpod-Ready--to--Code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/scott-haines/gcp-k8s-rancher) 
# Rancher with GCP

# Purpose
This package uses Terraform to create and provision Rancher on GCP.  It attempts to use Terraform objects wherever possible.

# Prerequisites
Older versions may work but are untested and unconfirmed.
Run `./bootstrap-environment` to run the interactive setup script.  It should be re-entrant so if it fails at any point it can safely be rerun.
1. Google Cloud SDK 245.0.0 [https://cloud.google.com/sdk/docs/quickstarts]
1. Terraform v0.12.24 [https://learn.hashicorp.com/terraform/getting-started/install.html]
1. jq jq-1.6 [https://stedolan.github.io/jq/]
1. GCP APIs enabled - they will be automatically enabled by the bootstrap-environment script.
    * cloudresourcemanager.googleapis.com `gcloud services enable cloudresourcemanager.googleapis.com`
    * compute.googleapis.com `gcloud services enable compute.googleapis.com`
    * container.googleapis.com `gcloud services enable container.googleapis.com`
    * iam.googleapis.com `gcloud services enable iam.googleapis.com`

# Getting Started
Run `./bootstrap-environment` and follow all instructions/prompts to setup your local environment.

# Cleaning Up
1. Run `terraform destroy` to remove all resources by terraform.
1. Remove the GCP service account (gcp-k8s-rancher) created by the bootstrap-environment script.
1. Delete the `secrets/gcp-k8s-rancher-key.json` file

# Resources
The following resources are created as part of this package

## variables.tf
All overridable variables are contained in this file.

If using `./bootstrap-environment` to initialize your environment your configuration will be placed into `terraform.tfvars`

Variables can be overridden using normal terraform methods (env vars begining with `TF_VAR_`, autovars, etc.)

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
