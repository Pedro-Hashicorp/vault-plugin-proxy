#!/bin/bash
# This script is meant to be run in the User Data of the Vault Server while it's booting.
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`
PUBLIC_HOSTNAME=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname`
PUBLIC_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4`
LOCAL_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4`
CLUSTER_NAME=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/Name`

$LOCAL_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4`
# Add Hashicorp Repo & install vault
sudo useradd --system --home /etc/vault.d --shell /bin/false vault
sudo mkdir --parents /etc/vault.d /var/lib/vault
sudo chown --recursive vault:vault /etc/vault.d /var/lib/vault
sudo mkdir -p /opt/vault/data
sudo mkdir -p /opt/vault/tls
sudo chmod 700 /opt/vault/data
sudo chown -R vault:vault /opt/vault
sudo chmod -R 700 /opt/vault/data




sudo mkdir /etc/vault.d
wget https://releases.hashicorp.com/vault/1.19.0+ent/vault_1.19.0+ent_linux_amd64.zip
sudo apt-get install unzip
unzip vault_1.19.0+ent_linux_amd64.zip
sudo mv vault /usr/local/bin/
sudo echo ${vault_service} | base64 --decode > /etc/systemd/system/vault.service
sudo echo ${vault_lic} | base64 --decode > /etc/vault.d/license.hclic

sudo chown vault:vault /etc/vault.d/license.hclic
sudo chmod 777 /etc/vault.d/license.hclic




# Bring some plugins
sudo mkdir -p /opt/vault/plugins
sudo wget -P /opt/vault/plugins https://releases.hashicorp.com/vault-plugin-secrets-keymgmt/0.16.0+ent/vault-plugin-secrets-keymgmt_0.16.0+ent_linux_amd64.zip
sudo chown -Rv vault:vault /opt/vault/plugins

#Configure Vault server
cat << EOVCF >/etc/vault.d/vault.hcl
ui = true
plugin_directory = "/opt/vault/plugins"
# HTTPS listener
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/tls.crt"
  tls_key_file  = "/opt/vault/tls/tls.key"
  tls_client_ca_file= "/opt/vault/tls/ca.crt"

}

storage "raft" {
  path = "/opt/vault/data"
  node_id = "$${HOSTNAME}"
  retry_join {
    auto_join = "provider=aws region=us-east-2 tag_key=aws:autoscaling:groupName tag_value=${asg_name}"
    leader_tls_servername = "${leader_tls_servername}"
  }
}

api_addr = "https://${aws_lb}:8200"
cluster_addr = "https://${aws_lb}:8201"

license_path = "/etc/vault.d/license.hclic"

seal "awskms" {
  region     = "${aws_region}"
  kms_key_id = "${kms_key}"
}
EOVCF

sudo cat << EOVK >/opt/vault/tls/tls.key
${certificate_key}
EOVK

sudo cat << EOVCRT >/opt/vault/tls/tls.crt
${certificate_pem}
${issuer_pem}
EOVCRT

systemctl enable vault
systemctl start vault
