#!/bin/bash -x

# Command line arguments
logstash_pass=$1
elk_version=$2

tmp_cert_file=/tmp/logstash
certs_dir=/etc/logstash/certs
logstash_cert_file=${certs_dir}/logstash

# Install logstash
sudo yum update -y >/dev/null && sudo yum install java-1.8.0-openjdk vim-enhanced -y
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
sudo rpm -i https://artifacts.elastic.co/downloads/logstash/logstash-${elk_version}.rpm

# Setup logstash configuration
sudo mv logstash.conf /etc/logstash/conf.d/
sudo chown root:root /etc/logstash/conf.d/logstash.conf

# Set up certs directory
sudo mkdir ${certs_dir}
sudo mv ${tmp_cert_file} ${certs_dir}
sudo chown root:root ${logstash_cert_file}
sudo chmod 640 ${logstash_cert_file}

# Create the PKCS12 private key and certificates
sudo openssl pkcs12 -in ${logstash_cert_file} -out ${certs_dir}/logstash.key -nocerts -nodes --passin pass:${logstash_pass}
sudo openssl pkcs12 -in ${logstash_cert_file} -out ${certs_dir}/logstash.cert -clcerts -nokeys --passin pass:${logstash_pass}
sudo openssl pkcs12 -in ${logstash_cert_file} -out ${certs_dir}/logstash-ca.cert -cacerts -nokeys -chain --passin pass:${logstash_pass}

sudo chmod 644 ${certs_dir}/logstash-ca.cert

# Start up logstash
sudo systemctl daemon-reload
sudo systemctl enable logstash
sudo systemctl restart logstash
