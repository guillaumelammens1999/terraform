terraform {
  backend "s3" {
    bucket         = "tf-bap-guillaume-eu-central-1"
    dynamodb_table = "tf-bap-guillaume-eu-central-1"
    key            = "stacks/ec2"
    region         = "eu-central-1"
    role_arn       = "arn:aws:iam::323997921258:role/cross_account_sharing_role"
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "usa"
  default_tags {
    tags = local.default_static_tags

  }
}


data "terraform_remote_state" "acm" {
  backend = "s3"
  config = {
    bucket   = "tf-bap-guillaume-eu-central-1"
    key      = join("/", ["env:", terraform.workspace, "stacks/acm"])
    region   = "eu-central-1"
    role_arn = "arn:aws:iam::323997921258:role/cross_account_sharing_role"
  }
}


data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket   = "tf-bap-guillaume-eu-central-1"
    key      = join("/", ["env:", terraform.workspace, "stacks/vpc"])
    region   = "eu-central-1"
    role_arn = "arn:aws:iam::323997921258:role/cross_account_sharing_role"
  }
}

# CloudWatch Alarm voor CPU-gebruik:
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-usage-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric triggers when CPU exceeds 70% for 1 minute"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.bar.name
  }
}

# Auto Scaling Policy om een nieuwe EC2-instance te starten wanneer het alarm triggert:
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.bar.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

# CloudWatch Alarm voor laag CPU-gebruik:
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-usage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "30" # Je kunt deze waarde aanpassen op basis van je behoeften
  alarm_description   = "This metric triggers when CPU is below 30% for 1 minute"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.bar.name
  }
}
# Create a CloudWatch Alarm for Unhealthy Hosts:

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "unhealthy-hosts-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "This metric triggers when there's at least one unhealthy host"
  dimensions = {
    TargetGroup  = aws_lb_target_group.bap_https.arn
    LoadBalancer = aws_lb.alb.arn
  }
  alarm_actions = [aws_autoscaling_policy.scale_up_unhealthy.arn]
}

# Create a New Auto Scaling Policy:
resource "aws_autoscaling_policy" "scale_up_unhealthy" {
  name                   = "scale-up-unhealthy-policy"
  autoscaling_group_name = aws_autoscaling_group.bar.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}


# Auto Scaling Policy om een EC2-instance te verwijderen wanneer het alarm triggert:
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.bar.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}


resource "aws_launch_template" "launch_template_bapmocktest" {
  name_prefix            = "LT-bap-terraform-augustus"
  image_id               = "ami-0a1daddd7ec555aa1"
  instance_type          = "t2.micro"
  user_data              = filebase64("${path.module}/userdata.sh")
  vpc_security_group_ids = [aws_security_group.bap_ec2.id]
  key_name               = var.key_name

}


##create ASG 
resource "aws_autoscaling_group" "bar" {
  name                = "application-wp-tf"
  vpc_zone_identifier = data.terraform_remote_state.vpc.outputs.private_subnets
  # availability_zones = ["eu-central-1a" , "eu-central-1b"]
  # health_check_type         = "ELB"
  health_check_grace_period = 300
  desired_capacity          = 1
  max_size                  = 2
  min_size                  = 1


  launch_template {
    id      = aws_launch_template.launch_template_bapmocktest.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "Guillaume"
    propagate_at_launch = true
  }
  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]

  }
}


resource "aws_lb" "alb" {
  name                       = "gui-lb-bap"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = data.terraform_remote_state.vpc.outputs.public_subnets
  security_groups            = [aws_security_group.bap_alb.id]
  enable_deletion_protection = false


  tags = {
    Environment = "production"
    name        = "Guillaume"
  }
}

resource "aws_lb_target_group" "bap_https" {
  name        = "targetgroup-bap-terraform"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 5
    interval            = 30
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "5"
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.bar.id
  lb_target_group_arn    = aws_lb_target_group.bap_https.arn
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bap_https.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.terraform_remote_state.acm.outputs.lb_acm

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bap_https.arn
  }
  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

}



resource "aws_security_group" "bap_alb" {
  name   = "sg_lb_tf"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
}

resource "aws_security_group_rule" "ingress_http_from_all_to_alb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bap_alb.id
}

resource "aws_security_group_rule" "ingress_https_from_all_to_alb" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bap_alb.id
}

resource "aws_security_group_rule" "egress_http_alb_to_ec2" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bap_alb.id
}
## Application / ASG / EC2
resource "aws_security_group" "bap_ec2" {
  name        = "sg_ASG"
  description = "bap EC2 security group"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
}

## Ingress rules
resource "aws_security_group_rule" "ingress_http_public" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bap_ec2.id
}

resource "aws_security_group_rule" "ingress_https_public" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bap_ec2.id
}

resource "aws_security_group_rule" "ingress_ssh_public" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bap_ec2.id
}

## Egress rules
resource "aws_security_group_rule" "egress_https" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bap_ec2.id
}

#einde
resource "aws_cloudfront_distribution" "LB_distribution" {
  origin {
    domain_name = aws_lb.alb.dns_name
    origin_id   = aws_lb.alb.dns_name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  # comment             = "Some comment"
  # default_root_object = "index.html"
  aliases = ["tf.bappende.link"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_lb.alb.dns_name

    min_ttl                  = 0
    default_ttl              = 0
    max_ttl                  = 0
    compress                 = true
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"

  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.amazon_issued.arn
    ssl_support_method  = "sni-only"
  }

}

data "aws_acm_certificate" "amazon_issued" {
  domain      = "tf.bappende.link"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
  provider    = aws.usa
}

# ROUTE53 Zone pullen voor record aan te maken
data "aws_route53_zone" "simplybap" {
  name         = "bappende.link"
  private_zone = false
  provider     = aws.usa
}

resource "aws_route53_record" "alias" {
  name            = "tf"
  type            = "A"
  allow_overwrite = true
  alias {
    evaluate_target_health = true
    name                   = aws_cloudfront_distribution.LB_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.LB_distribution.hosted_zone_id
  }
  zone_id = data.aws_route53_zone.simplybap.zone_id
}
