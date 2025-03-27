# Finding Latest Ubuntu AMI

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["*ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_launch_template" "vault" {
  name_prefix   = random_pet.env.id
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.vault-kms-unseal.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.allow_tls.id]
  }
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${random_pet.env.id}-vault"
    }
  }

  user_data = base64encode(templatefile("userdata.sh", {
    certificate_key       = acme_certificate.certificate.private_key_pem,
    certificate_pem       = acme_certificate.certificate.certificate_pem,
    issuer_pem            = acme_certificate.certificate.issuer_pem,
    kms_key               = aws_kms_key.vault.id,
    asg_name              = random_pet.env.id,
    leader_tls_servername = var.vault_fqdn,
    aws_region            = var.region,
    vault_service         = filebase64("${path.module}/utils/vault.service"),
    vault_lic              = filebase64("${path.module}/utils/vault.hclic"),
    aws_lb                = aws_lb.vnlb.dns_name
  }))
}

resource "aws_autoscaling_group" "vault" {
  name         = random_pet.env.id
  max_size     = 3
  min_size     = 0
  force_delete = true
  launch_template {
    id      = aws_launch_template.vault.id
    version = "$Latest"
  }
  vpc_zone_identifier = module.vpc.public_subnets
  target_group_arns   = [aws_lb_target_group.vtls.arn]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vault-kms-unseal" {
  statement {
    sid       = "VaultKMSUnseal"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "ec2:DescribeInstances"
    ]
  }
}

resource "aws_iam_role" "vault-kms-unseal" {
  name               = "vault-kms-role-${random_pet.env.id}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "vault-kms-unseal" {
  name   = "Vault-KMS-Unseal-${random_pet.env.id}"
  role   = aws_iam_role.vault-kms-unseal.id
  policy = data.aws_iam_policy_document.vault-kms-unseal.json
}

resource "aws_iam_instance_profile" "vault-kms-unseal" {
  name = "vault-kms-unseal-${random_pet.env.id}"
  role = aws_iam_role.vault-kms-unseal.name
}


##Squid instance
resource "aws_instance" "squid" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = var.key_name
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[1]
  vpc_security_group_ids      = [aws_security_group.proxy_allow_all.id]
  user_data = base64encode(templatefile("utils/squid.userdata.sh", {
    vpc_cidr = var.cidr
  }))

  tags = {
    Name = "${random_pet.env.id}-proxy"
  }
}
