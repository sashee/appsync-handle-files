resource "aws_cognito_user" "user1" {
  user_pool_id = aws_cognito_user_pool.pool.id
  username     = "user1"
  attributes = {
    email = "user1@example.com"
  }
  password = "Password.1"
}

resource "aws_cognito_user" "user2" {
  user_pool_id = aws_cognito_user_pool.pool.id
  username     = "user2"
  attributes = {
    email = "user2@example.com"
  }
  password = "Password.1"
}

locals {
  images = [
    { imageid : "CT2nhSJOO8U", userid : aws_cognito_user.user1.sub, public : true },
    { imageid : "MzR7mbWjCJw", userid : aws_cognito_user.user1.sub, public : false },
    { imageid : "5fedGbqYwvM", userid : aws_cognito_user.user1.sub, public : true },
    { imageid : "dtj1pzWwxho", userid : aws_cognito_user.user2.sub, public : true },
    { imageid : "jN5pk0lbv4E", userid : aws_cognito_user.user2.sub, public : true },
    { imageid : "OLnBaWJJj4k", userid : aws_cognito_user.user2.sub, public : true },
    { imageid : "d0jtkKL8QZY", userid : aws_cognito_user.user1.sub, public : true },
    { imageid : "8qH4GSYBiSA", userid : aws_cognito_user.user1.sub, public : true },
    { imageid : "uEOQ3jxwFI4", userid : aws_cognito_user.user2.sub, public : true },
    { imageid : "C2kJ9lBQCr8", userid : aws_cognito_user.user2.sub, public : true },
    { imageid : "dC2FsjoXsPQ", userid : aws_cognito_user.user1.sub, public : false },
    { imageid : "F3rDBnQQbQU", userid : aws_cognito_user.user2.sub, public : false },
  ]
}

data "external" "images" {
  count = length(local.images)
  program = ["bash", "-c", <<EOT
INPUT="$(cat)"
IMAGEID=$(echo "$INPUT" | jq -r '.imageid');
TMPDIR=$(echo "$INPUT" | jq -r '.tmpdir')
BASENAME="$(pwd)/$TMPDIR"
URL="https://unsplash.com/photos/$IMAGEID/download?force=true&w=1300"
URLHASH=$(echo -n "$URL" | sha256sum | awk '{print $1}')
FILENAME="$BASENAME/$URLHASH.jpg";
(
	mkdir -p "$BASENAME";
	if [ ! -f "$FILENAME" ]; then
		curl -L -o "$FILENAME" "$URL";
	fi
) >&2 && echo "{\"file\": \"$FILENAME\"}"
EOT
  ]
  working_dir = "/tmp"
  query = {
    imageid = local.images[count.index].imageid
    tmpdir  = random_id.id.hex
  }
}

resource "aws_s3_object" "images" {
  count  = length(local.images)
  key    = basename(data.external.images[count.index].result.file)
  source = data.external.images[count.index].result.file
  bucket = aws_s3_bucket.bucket.bucket
  etag   = filemd5(data.external.images[count.index].result.file)

  # open in the browser
  content_disposition = "inline"
  content_type        = "image/jpg"
}

resource "aws_dynamodb_table_item" "images" {
  count      = length(local.images)
  table_name = aws_dynamodb_table.image.name
  hash_key   = aws_dynamodb_table.image.hash_key
  range_key  = aws_dynamodb_table.image.range_key
  item       = <<ITEM
{
  "userid": {"S": "${local.images[count.index].userid}"},
	"key": {"S": "${basename(data.external.images[count.index].result.file)}"},
	"public": {"BOOL": ${local.images[count.index].public}},
	"userid#public": {"S": "${local.images[count.index].userid}#${local.images[count.index].public}"},
	"added": {"N": "${1677932231056 + count.index}"}
}
ITEM
}

resource "aws_dynamodb_table_item" "user1" {
  table_name = aws_dynamodb_table.user.name
  hash_key   = aws_dynamodb_table.user.hash_key
  item       = <<ITEM
{
  "id": {"S": "${aws_cognito_user.user1.sub}"},
	"username": {"S": "User 1"}
}
ITEM
}
resource "aws_dynamodb_table_item" "user2" {
  table_name = aws_dynamodb_table.user.name
  hash_key   = aws_dynamodb_table.user.hash_key
  item       = <<ITEM
{
  "id": {"S": "${aws_cognito_user.user2.sub}"},
	"username": {"S": "User 2"}
}
ITEM
}

