variable REGION {
  default = "us-east1"
}

variable "PROJECT_ID" {}


variable ZONE {
  default = "us-east1-b"
}

variable vpc {
  default = {
    name              = "vpc"
    subnet_name       = "vpc-subnet"
    subnet_cidr_block = "10.0.0.0/24"
  }
}

variable bastion {
  default = {
    name     = "bastion"
    size     = "f1-micro"
    image    = "debian-cloud/debian-9"
    username = ""
    dns = {
      use_google_dns = false
      username       = ""
      password       = ""
      fqdn           = ""
    }
  }
}
