output "proxy_ip" {
  value = aws_instance.squid.private_ip
}

output "key_name" {
  value = length(data.aws_key_pair.existing.id) > 0 ? data.aws_key_pair.existing.key_name : aws_key_pair.new_key[0].key_name
}

output "key_path" {
  value = length(data.aws_key_pair.existing.id) > 0 ? "Existing key pair used" : "my-key.pem"
}