variable "state_bucket_name" {
    type = string
    description = "S3 bucket for remote state"
}

variable "lock_table_name" {
    type = string
    description = "DynamoDB table for state locking"
}


# by using the below we can provide the vaules to variables
# terraform apply \
# -var="state_bucket_name=myorg-terraform-state" \
# -var="lock_table_name=terraform-locks"