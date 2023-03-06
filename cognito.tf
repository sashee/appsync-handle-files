resource "aws_cognito_user_pool" "pool" {
  name = "test-${random_id.id.hex}"
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "client"
  user_pool_id = aws_cognito_user_pool.pool.id

  allowed_oauth_flows                  = ["code"]
  callback_urls                        = ["https://${aws_cloudfront_distribution.distribution.domain_name}"]
  logout_urls                          = ["https://${aws_cloudfront_distribution.distribution.domain_name}"]
  allowed_oauth_scopes                 = ["openid"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "test-${random_id.id.hex}"
  user_pool_id = aws_cognito_user_pool.pool.id
}
