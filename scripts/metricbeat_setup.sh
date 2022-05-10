#!/bin/bash -x

# Command line arguments
metricbeat_pass=$1
elk_version=$2

tmp_cert_file=/tmp/metricbeat
certs_dir=/etc/metricbeat/certs
metricbeat_cert_file=${certs_dir}/metricbeat

# Install metricbeat
sudo yum update -y >/dev/null && sudo yum install vim-enhanced -y
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
sudo rpm -i https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-${elk_version}-x86_64.rpm

# Set up metricbeat configuration
sudo mv metricbeat.yml /etc/metricbeat/
sudo chown root:root /etc/metricbeat/metricbeat.yml

# Set up certs directory
sudo mkdir ${certs_dir}
sudo mv ${tmp_cert_file} ${certs_dir}
sudo chown root:root ${metricbeat_cert_file}
sudo chmod 640 ${metricbeat_cert_file}

# Create the PKCS12 private key and certificates
openssl pkcs12 -in ${metricbeat_cert_file} -out ${certs_dir}/metricbeat.key -nocerts -nodes --passin pass:${metricbeat_pass}
openssl pkcs12 -in ${metricbeat_cert_file} -out ${certs_dir}/metricbeat.cert -clcerts -nokeys --passin pass:${metricbeat_pass}
openssl pkcs12 -in ${metricbeat_cert_file} -out ${certs_dir}/metricbeat-ca.cert -cacerts -nokeys -chain --passin pass:${metricbeat_pass}

sudo chmod 644 ${certs_dir}/metricbeat.key
sudo chmod 644 ${certs_dir}/metricbeat.cert
sudo chmod 644 ${certs_dir}/metricbeat-ca.cert

# Set up metricbeat system module
sudo systemctl daemon-reload
sudo systemctl enable metricbeat
sudo metricbeat modules enable system
sudo metricbeat setup

# Start up metricbeat
sudo systemctl restart metricbeat.service
