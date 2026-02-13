# ==========================================
# LAMBDA FUNCTION
# ==========================================
resource "aws_lambda_function" "myfunc" {
  filename         = data.archive_file.zip_the_python_code.output_path
  source_code_hash = data.archive_file.zip_the_python_code.output_base64sha256
  function_name    = "myfunc"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "func.lambda_handler"
  runtime          = "python3.12"

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role
  ]
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_policy" "iam_policy_for_resume_project" {
  name        = "aws_iam_policy_for_terraform_resume_project_policy"
  path        = "/"
  description = "AWS IAM Policy for managing the resume project role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
        Effect   = "Allow"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Resource = [
          "arn:aws:dynamodb:ap-south-1:447572331640:table/Cloudresume-test",
          "arn:aws:dynamodb:ap-south-1:447572331640:table/Cloudresume-test/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_resume_project.arn
}

data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_file = "${path.module}/lambda/func.py"
  output_path = "${path.module}/lambda/func.zip"
}

resource "aws_lambda_permission" "allow_function_url" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.myfunc.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "allow_public_invoke" {
  statement_id  = "AllowPublicInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.myfunc.function_name
  principal     = "*"
}

# Lambda Function URL with CORS
resource "aws_lambda_function_url" "url1" {
  function_name      = aws_lambda_function.myfunc.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["*"]
    max_age       = 86400
  }

  depends_on = [aws_lambda_permission.allow_function_url]
}

locals {
  resume_subdomain = "sudeshna.resume.animals4life.shop"
  
  # Determine the correct path to html5up-strata
  # For local: ../html5up-strata (when running from infra/)
  # For GitHub Actions: html5up-strata (when running from project root with working-directory: infra)
  website_dir = fileexists("${path.module}/../html5up-strata/index.html") ? "${path.module}/../html5up-strata" : "${path.module}/html5up-strata"
}

# ==========================================
# DYNAMODB
# ==========================================
resource "aws_dynamodb_table" "cloudresume_table" {
  name         = "Cloudresume-test"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "initial_count" {
  table_name = aws_dynamodb_table.cloudresume_table.name
  hash_key   = aws_dynamodb_table.cloudresume_table.hash_key

  item = <<ITEM
{
  "id": {"S": "0"},
  "views": {"N": "0"}
}
ITEM
}

# ==========================================
# S3 BUCKET (CloudFront Origin - NOT Static Website)
# ==========================================
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "resume_bucket" {
  bucket        = "animals4life-resume-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# Keep bucket private - CloudFront will access it via OAC
resource "aws_s3_bucket_public_access_block" "resume_bucket_pab" {
  bucket = aws_s3_bucket.resume_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Generate config.js with Lambda URL dynamically
resource "local_file" "config_js" {
  content = <<-EOT
    const CONFIG = {
      LAMBDA_URL: "${aws_lambda_function_url.url1.function_url}"
    };
  EOT
  filename = "${local.website_dir}/assets/js/config.js"

  depends_on = [aws_lambda_function_url.url1]
}

# Upload website files
resource "aws_s3_object" "website_files" {
  for_each = fileset(local.website_dir, "**")

  bucket       = aws_s3_bucket.resume_bucket.id
  key          = each.value
  source       = "${local.website_dir}/${each.value}"
  etag         = filemd5("${local.website_dir}/${each.value}")
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), "application/octet-stream")

  depends_on = [
    local_file.config_js,
    aws_s3_bucket_public_access_block.resume_bucket_pab
  ]
}

locals {
  mime_types = {
    ".html"  = "text/html"
    ".css"   = "text/css"
    ".js"    = "application/javascript"
    ".json"  = "application/json"
    ".png"   = "image/png"
    ".jpg"   = "image/jpeg"
    ".jpeg"  = "image/jpeg"
    ".gif"   = "image/gif"
    ".svg"   = "image/svg+xml"
    ".ico"   = "image/x-icon"
    ".txt"   = "text/plain"
    ".pdf"   = "application/pdf"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"   = "font/ttf"
    ".eot"   = "application/vnd.ms-fontobject"
    ".otf"   = "font/otf"
  }
}

# ==========================================
# ACM CERTIFICATE (in us-east-1 for CloudFront)
# ==========================================
resource "aws_acm_certificate" "cert" {
  provider    = aws.us_east_1
  domain_name = "animals4life.shop"

  subject_alternative_names = [
    local.resume_subdomain
  ]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ==========================================
# ROUTE53 HOSTED ZONE
# ==========================================
data "aws_route53_zone" "main" {
  name         = "animals4life.shop"
  private_zone = false
}

# DNS validation record for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ==========================================
# CLOUDFRONT DISTRIBUTION
# ==========================================
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "animals4life-oac"
  description                       = "OAC for animals4life.shop S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "resume_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  wait_for_deployment = true
  default_root_object = "index.html"

  aliases = [
    "animals4life.shop",
    local.resume_subdomain
  ]

  depends_on = [
    aws_acm_certificate_validation.cert,
    aws_s3_object.website_files
  ]

  origin {
    domain_name              = aws_s3_bucket.resume_bucket.bucket_regional_domain_name
    origin_id                = "S3-animals4life"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-animals4life"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }
}

# Bucket policy to allow CloudFront OAC to read objects
resource "aws_s3_bucket_policy" "resume_bucket_policy" {
  bucket = aws_s3_bucket.resume_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.resume_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.resume_distribution.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_cloudfront_distribution.resume_distribution]

  lifecycle {
    create_before_destroy = true
  }
}

# ==========================================
# ROUTE53 DNS RECORDS
# ==========================================
# A record for animals4life.shop pointing to CloudFront
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "animals4life.shop"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.resume_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# A record for sudeshna.resume.animals4life.shop pointing to CloudFront
resource "aws_route53_record" "resume_subdomain" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.resume_subdomain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.resume_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# ==========================================
# OUTPUTS
# ==========================================
output "nameservers" {
  value       = data.aws_route53_zone.main.name_servers
  description = "Copy these nameservers to GoDaddy!"
}

output "cloudfront_domain" {
  value       = aws_cloudfront_distribution.resume_distribution.domain_name
  description = "CloudFront distribution domain"
}

output "website_url" {
  value       = "https://${local.resume_subdomain}"
  description = "Your website URL (after DNS propagation)"
}

output "lambda_function_url" {
  value       = aws_lambda_function_url.url1.function_url
  description = "Lambda Function URL for visitor counter"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.resume_bucket.id
  description = "S3 Bucket Name"
}

output "certificate_arn" {
  value       = aws_acm_certificate.cert.arn
  description = "ACM Certificate ARN"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.resume_distribution.id
  description = "CloudFront Distribution ID"
}
