# name should match `terraform.backend["s3"].bucket` from ../terraform.tf
resource "aws_s3_bucket" "chad-saac02-playground-tfstate" {
  bucket = "chad-saac02-playground-tfstate"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

# name should match `terraform.backend["s3"].dynamodb_table` from ../terraform.tf
resource "aws_dynamodb_table" "chad-saac02-playground-tfstate" {
  name = "chad-saac02-playground-tfstate"
  hash_key = "LockID"
  read_capacity = 1
  write_capacity = 1

  attribute {
    name = "LockID"
    type = "S"
  }
}
