data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "C:/Users/Terraform/Terraform_demo/1VPC/terraform.tfstate"
  }
}