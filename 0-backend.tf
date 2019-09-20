terraform {
  backend "gcs" {
    credentials = "secrets/service-account-credentials.json"
    bucket      = "lfd259-shaines"
    prefix      = "terraform/state"
  }
}
