terraform {
  backend "s3" {
    bucket       = "bits-hw-nsp4-terraform-state"
    key          = "NSP-4-S2-S25App/terraform.tfstate"
    region       = "ap-south-2"
    encrypt      = true
    use_lockfile = true
  }
}
