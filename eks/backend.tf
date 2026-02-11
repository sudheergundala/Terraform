terraform {
  backend "s3" {
    bucket = "dev_terraform_state"
    # bucket name which we have already created to store the state.
    dynamodb_table = "dev_terraform_locks"
    # dynamoDB table which will be used for locking the state.
    key = "eks/dev/terraform.tfstate"
    # path of the statefile. This will be changing according to the project and env.
    region = "us-east-1"
    # This is the same region where the bucket resides.
    encrypt = true  
    # This enables the encryption at rest.
  }
}
