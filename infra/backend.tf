terraform {
  backend "s3" {
    bucket         = "cloud-resume-tf-state-ap-south-1-123"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
  }
}
