resource "aws_dynamodb_table" "image" {
  name         = "image-${random_id.id.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "key"
  attribute {
    name = "userid"
    type = "S"
  }
  attribute {
    name = "key"
    type = "S"
  }
  attribute {
    name = "userid#public"
    type = "S"
  }
  attribute {
    name = "added"
    type = "N"
  }

  global_secondary_index {
    name            = "userid"
    hash_key        = "userid"
    range_key       = "added"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "useridPublic"
    hash_key        = "userid#public"
    range_key       = "added"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "user" {
  name         = "user-${random_id.id.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

