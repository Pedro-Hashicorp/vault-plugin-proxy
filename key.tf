data "aws_key_pair" "existing" {
  key_name = var.key_name
}

resource "tls_private_key" "new_key" {
  count = length(data.aws_key_pair.existing.id) > 0 ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_kms_key" "vault" {
  description             = "Vault unseal key"
  deletion_window_in_days = 7

  tags = {
    Name = "vault-kms-unseal-${random_pet.env.id}"
  }
}


resource "aws_key_pair" "new_key" {
  count      = length(data.aws_key_pair.existing.id) > 0 ? 0 : 1
  key_name   = "my-key"
  public_key = tls_private_key.new_key[0].public_key_openssh
}

# Save the private key to a local file (only if created)
resource "local_file" "private_key" {
  count    = length(data.aws_key_pair.existing.id) > 0 ? 0 : 1
  content  = tls_private_key.new_key[0].private_key_pem
  filename = "my-key.pem"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.letsencrypt_reg_email
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = var.vault_fqdn

  dns_challenge {
    provider = "route53"
  }
}
