#!/bin/bash -x

# Command line arguments
logstash_private_dns=$1
logstash_private_ip=$2
ca_pass=$3
logstash_pass=$4
ssh_key_file=$5
user_name=$6

ca_file=/etc/elasticsearch/certs/ca
logstash_cert_file=/etc/elasticsearch/certs/logstash

# Generate logstash certificate
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert \
    --ca ${ca_file} \
    --ca-pass ${ca_pass} \
    --name logstash \
    --dns ${logstash_private_dns} \
    --ip ${logstash_private_ip} \
    --out ${logstash_cert_file} \
    --pass ${logstash_pass}

# Copy the certificate to the logstash server
sudo scp -i ${ssh_key_file} \
    -o StrictHostKeyChecking=no \
    ${logstash_cert_file} \
    ${user_name}@${logstash_private_ip}:/tmp
