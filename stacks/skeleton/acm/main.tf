terraform {
  backend "s3" {
    bucket         = "tf-bap-guillaume-eu-central-1"
    dynamodb_table = "tf-bap-guillaume-eu-central-1"
    key            = "stacks/acm"
    region         = "eu-central-1"
    role_arn       = "arn:aws:iam::323997921258:role/cross_account_sharing_role"
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = local.default_static_tags

  }
  alias = "us-east-1"
}

data "aws_route53_zone" "example" {
  name         = "bappende.link"
  private_zone = false
}

resource "aws_acm_certificate" "crm" {
  domain_name       = "tf.bappende.link"
  # subject_alternative_names = [ "*.bappende.link", ]
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  provider = aws.us-east-1 
}

resource "aws_route53_record" "example" {
  for_each = {
    for dvo in aws_acm_certificate.crm.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.example.zone_id
}

resource "aws_acm_certificate_validation" "example" {
  certificate_arn         = aws_acm_certificate.crm.arn
  validation_record_fqdns = [for record in aws_route53_record.example : record.fqdn]
  provider = aws.us-east-1
}


######################## ALB ACM EUCENTRAL1!

data "aws_route53_zone" "example2" {
  name         = "bappende.link"
  private_zone = false
}

resource "aws_acm_certificate" "crm2" {
  domain_name       = "tf.bappende.link"
  # subject_alternative_names = [ "*.bappende.link", ]
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "example2" {
  for_each = {
    for dvo in aws_acm_certificate.crm2.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.example.zone_id
}

resource "aws_acm_certificate_validation" "example2" {
  certificate_arn         = aws_acm_certificate.crm2.arn
  validation_record_fqdns = [for record in aws_route53_record.example2 : record.fqdn]
}
