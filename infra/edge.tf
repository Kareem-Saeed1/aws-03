resource "aws_acm_certificate" "app" {

  domain_name       = local.app_host
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }

}
resource "aws_acm_certificate" "static" {

  provider          = aws.edge
  domain_name       = local.static_host
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }

}
resource "aws_route53_record" "app_validation" {

  for_each = {
    for d in aws_acm_certificate.app.domain_validation_options : d.domain_name => d
  }
  zone_id = var.hosted_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60

}
resource "aws_route53_record" "static_validation" {

  for_each = {
    for d in aws_acm_certificate.static.domain_validation_options : d.domain_name => d
  }
  zone_id = var.hosted_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60

}
resource "aws_acm_certificate_validation" "app" {

  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.app_validation : r.fqdn]

}
resource "aws_acm_certificate_validation" "static" {

  provider                = aws.edge
  certificate_arn         = aws_acm_certificate.static.arn
  validation_record_fqdns = [for r in aws_route53_record.static_validation : r.fqdn]

}
resource "aws_lb" "app" {

  name                       = local.name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection

}
resource "aws_lb_target_group" "app" {

  name                 = local.name
  port                 = 8000
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3

  }

}
resource "aws_lb_listener" "http" {

  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"

    }

  }

}
resource "aws_lb_listener" "https" {

  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.app.certificate_arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Unknown host"
      status_code  = "404"

    }

  }

}
resource "aws_lb_listener_rule" "app" {

  listener_arn = aws_lb_listener.https.arn
  priority     = 100
  condition {
    host_header {
      values = [local.app_host]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn

  }

}
resource "aws_route53_record" "app" {

  zone_id = var.hosted_zone_id
  name    = local.app_host
  type    = "A"
  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true

  }

}
resource "aws_cloudfront_origin_access_control" "static" {

  name                              = "${local.name}-static"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

}
resource "aws_cloudfront_distribution" "static" {

  enabled         = true
  is_ipv6_enabled = true
  aliases         = [local.static_host]
  price_class     = "PriceClass_100"
  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "static-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.static.id

  }
  default_cache_behavior {

    target_origin_id           = "static-s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"

  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {

    acm_certificate_arn      = aws_acm_certificate_validation.static.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"

  }

}
resource "aws_s3_bucket_policy" "static" {

  bucket = aws_s3_bucket.static.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Sid = "CloudFrontRead", Effect = "Allow", Principal = {
          Service = "cloudfront.amazonaws.com"
          }, Action = "s3:GetObject", Resource = "${aws_s3_bucket.static.arn}/*", Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.static.arn
          }
        }
      },
      {
        Sid = "DenyInsecureTransport", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.static.arn, "${aws_s3_bucket.static.arn}/*"], Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

}
resource "aws_route53_record" "static" {

  for_each = toset(["A", "AAAA"])
  zone_id  = var.hosted_zone_id
  name     = local.static_host
  type     = each.value
  alias {
    name                   = aws_cloudfront_distribution.static.domain_name
    zone_id                = aws_cloudfront_distribution.static.hosted_zone_id
    evaluate_target_health = false

  }

}
