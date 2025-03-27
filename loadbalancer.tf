
resource "aws_lb_target_group" "vtls" {
  name     = "vtls"
  port     = 8200
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb" "vnlb" {
  name               = random_pet.env.id
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets
  tags = {
    Environment = random_pet.env.id
  }
}

data "aws_route53_zone" "selected" {
  name = var.vault_fqdn
}

resource "aws_route53_record" "vault_addr" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.vault_fqdn
  type    = "CNAME"
  ttl     = 30
  records = [aws_lb.vnlb.dns_name]
}

resource "aws_lb_listener" "ssl" {
  load_balancer_arn = aws_lb.vnlb.arn
  port              = "443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vtls.arn
  }
}
