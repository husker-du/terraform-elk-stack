#!/bin/bash -x

# Command line arguments
metricbeat_private_dns=$1
metricbeat_private_ip=$2
ca_pass=$3
metricbeat_pass=$4
ssh_key_file=$5
user_name=$6

ca_file=/etc/elasticsearch/certs/ca
metricbeat_cert_file=/etc/elasticsearch/certs/metricbeat

# Generate metricbeat certificate
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert \
    --ca ${ca_file} \
    --ca-pass ${ca_pass} \
    --name metricbeat \
    --dns ${metricbeat_private_dns} \
    --ip ${metricbeat_private_ip} \
    --out ${metricbeat_cert_file} \
    --pass ${metricbeat_pass}

# Copy the certificate to the metricbeat server
sudo scp -i ${ssh_key_file} \
    -o StrictHostKeyChecking=no \
    ${metricbeat_cert_file} \
    ${user_name}@${metricbeat_private_ip}:/tmp
