#!/bin/bash
# This script is meant to be run in the User Data of the Squid Server while it's booting for the first time.

sudo apt-get update && sudo apt-get install squid -y

#Allow everyone to talk to proxy
cat << EOSCF >/etc/squid/conf.d/allow.conf
acl vpc src ${vpc_cidr}
http_access allow vpc
http_access allow all
EOSCF

systemctl enable squid
systemctl restart squid
