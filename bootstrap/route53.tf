resource "aws_route53_zone" "main" {
  name = "animals4life.shop"

  lifecycle {
    prevent_destroy = true
  }
}
