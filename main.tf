provider "aws" {
}
resource "random_id" "id" {
  byte_length = 8
}
resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}
data "aws_iam_policy_document" "appsync" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      aws_dynamodb_table.image.arn,
      "${aws_dynamodb_table.image.arn}/*",
      aws_dynamodb_table.user.arn,
    ]
  }
  statement {
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [
      aws_lambda_function.lambda.arn,
      aws_lambda_function.image_lambda.arn,
    ]
  }
}
resource "aws_iam_role_policy" "appsync" {
  role   = aws_iam_role.appsync.id
  policy = data.aws_iam_policy_document.appsync.json
}
resource "aws_appsync_graphql_api" "appsync" {
  name                = "file-handling-example"
  schema              = file("schema.graphql")
  authentication_type = "AMAZON_COGNITO_USER_POOLS"
  user_pool_config {
    default_action = "ALLOW"
    user_pool_id   = aws_cognito_user_pool.pool.id
  }
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

resource "aws_iam_role" "appsync_logs" {
  assume_role_policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
		"Effect": "Allow",
		"Principal": {
			"Service": "appsync.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
		}
	]
}
POLICY
}
data "aws_iam_policy_document" "appsync_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}
resource "aws_iam_role_policy" "appsync_logs" {
  role   = aws_iam_role.appsync_logs.id
  policy = data.aws_iam_policy_document.appsync_policy.json
}
resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.appsync.id}"
  retention_in_days = 14
}

resource "aws_appsync_datasource" "ddb_images" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "ddb_images"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"
  dynamodb_config {
    table_name = aws_dynamodb_table.image.name
  }
}

resource "aws_appsync_datasource" "ddb_users" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "ddb_users"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"
  dynamodb_config {
    table_name = aws_dynamodb_table.user.name
  }
}

resource "aws_appsync_datasource" "lambda_signer" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "lambda_signer"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AWS_LAMBDA"
  lambda_config {
    function_arn = aws_lambda_function.lambda.arn
  }
}

resource "aws_appsync_datasource" "lambda_image_uploader" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "lambda_image_uploader"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AWS_LAMBDA"
  lambda_config {
    function_arn = aws_lambda_function.image_lambda.arn
  }
}
