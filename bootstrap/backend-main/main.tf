# create the s3 bucket and dynamoDB table to use in the backend.tf file

# S3 bucket.
resource "aws_s3_bucket" "s3_state" {
    bucket = var.state_bucket_name
    versioning{
        enabled = true
    }
    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default{
                sse_algorithm = "AES256"
            }
        }
    }
    lifecycle{
        prevent_destroy = true
    }
}

# dynamoDB table

resource "aws_dynamodb_table" "state_lock" {
    name = var.lock_table_name
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}