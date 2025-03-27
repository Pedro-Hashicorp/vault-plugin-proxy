data "aws_key_pair" "existing" {
  key_name = var.key_name
}

resource "tls_private_key" "new_key" {
  count = length(data.aws_key_pair.existing.id) > 0 ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 2048
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

output "key_name" {
  value = length(data.aws_key_pair.existing.id) > 0 ? data.aws_key_pair.existing.key_name : aws_key_pair.new_key[0].key_name
}

output "key_path" {
  value = length(data.aws_key_pair.existing.id) > 0 ? "Existing key pair used" : "my-key.pem"
}