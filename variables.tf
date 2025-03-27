variable "region" {
  description = "The region of the VPC"
  type        = string
  default     = "us-east-1"
}

variable "public_subnets" {
  type = list(any)
  default = [
    "10.0.20.0/24",
    "10.0.21.0/24",
    "10.0.22.0/24",
  ]
}
variable "cidr" {
  default = "10.0.0.0/16"
}

variable "vault_fqdn" {
  type = string
}

variable "key_name" {
  type    = string
  default = ""
}

variable "letsencrypt_reg_email" {
  type = string
}
