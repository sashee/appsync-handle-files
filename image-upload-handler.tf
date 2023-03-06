data "archive_file" "image_lambda_zip" {
  type        = "zip"
  output_path = "/tmp/image-upload-handler-${random_id.id.hex}.zip"
  source {
    content  = file("image-upload-handler.mjs")
    filename = "image-upload-handler.mjs"
  }
}

resource "aws_lambda_function" "image_lambda" {
  function_name    = "image-upload-handler-${random_id.id.hex}"
  filename         = data.archive_file.image_lambda_zip.output_path
  source_code_hash = data.archive_file.image_lambda_zip.output_base64sha256
  environment {
    variables = {
      Bucket : aws_s3_bucket.bucket.bucket,
      ImageTable : aws_dynamodb_table.image.name,
    }
  }
  timeout = 30
  handler = "image-upload-handler.handler"
  runtime = "nodejs18.x"
  role    = aws_iam_role.image_lambda_exec.arn
}

data "aws_iam_policy_document" "image_lambda_exec_role_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
  statement {
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.bucket.arn}/*"
    ]
  }
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
    ]
    resources = [
      aws_dynamodb_table.image.arn,
    ]
  }
}
resource "aws_cloudwatch_log_group" "image_lambda_loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.image_lambda.function_name}"
  retention_in_days = 14
}
resource "aws_iam_role_policy" "image_lambda_exec_role" {
  role   = aws_iam_role.image_lambda_exec.id
  policy = data.aws_iam_policy_document.image_lambda_exec_role_policy.json
}
resource "aws_iam_role" "image_lambda_exec" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

