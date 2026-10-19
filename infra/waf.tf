resource "aws_wafv2_web_acl" "app" {

  name  = local.name
  scope = "REGIONAL"
  default_action {
    allow {

    }
  }
  dynamic "rule" {

    for_each = {
      AWSManagedRulesCommonRuleSet = 10, AWSManagedRulesKnownBadInputsRuleSet = 20, AWSManagedRulesSQLiRuleSet = 30
    }
    content {

      name     = rule.key
      priority = rule.value
      override_action {
        none {

        }
      }
      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"

        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = false

      }

    }

  }
  rule {

    name     = "RateLimit"
    priority = 40
    action {
      block {

      }
    }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"

      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = false

    }

  }
  # Deterministic, harmless validation rule. Does not weaken the other rules.
  rule {

    name     = "EvidenceTestBlock"
    priority = 1
    action {
      block {

      }
    }
    statement {
      byte_match_statement {

        positional_constraint = "EXACTLY"
        search_string         = "block-me"
        field_to_match {
          single_header {
            name = "x-lab-waf-test"
          }
        }
        text_transformation {
          priority = 0
          type     = "NONE"

        }

      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "EvidenceTestBlock"
      sampled_requests_enabled   = false

    }

  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.name
    sampled_requests_enabled   = false

  }

}
resource "aws_wafv2_web_acl_association" "app" {

  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.app.arn

}
resource "aws_cloudwatch_log_group" "waf" {

  name              = "aws-waf-logs-${local.name}"
  retention_in_days = 14

}
resource "aws_wafv2_web_acl_logging_configuration" "app" {

  resource_arn            = aws_wafv2_web_acl.app.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

}
