variable REGION {
  default = "us-east1"
}

variable "PROJECT_ID" {}


variable ZONE {
  default = "us-east1-b"
}

variable vpc_name {
  default = "vpc"
}

variable vpc_subnet_name {
  default = "vpc-subnet"
}

variable vpc_subnet_cidr_block {
    default = "10.0.0.0/24"
}

variable bastion_name {
  default = "bastion"
}

variable bastion_size {
  default = "f1-micro"
}

variable bastion_image {
  default = "debian-cloud/debian-9"
}

variable bastion_username {
  default = "defaultuser"
}

variable bastion_dns_use_google_dns {
  default = false
}

variable bastion_dns_username {
  default = ""
}

variable bastion_dns_password {
  default = ""
}

variable bastion_dns_fqdn {
  default = ""
}

variable rancher_web_name {
  default = "rancher-web"
}

variable rancher_web_size {
  default = "g1-small"
}

variable rancher_web_image {
  default = "debian-cloud/debian-9"
}

variable rancher_web_dns_use_google_dns {
  default = false
}

variable rancher_web_dns_username {
  default = ""
}

variable rancher_web_dns_password {
  default = ""
}

variable rancher_web_dns_fqdn {
  default = ""
}