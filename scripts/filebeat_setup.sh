#!/bin/bash -x

# Command line arguments
elk_version=$1

# Install filebeat
sudo yum update -y >/dev/null && sudo yum install vim-enhanced -y
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearc
sudo rpm -i https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${elk_version}-x86_64.rpm

# Set up filebeat configuration
sudo mv filebeat.yml /etc/filebeat/
sudo chown root:root /etc/filebeat/filebeat.yml

# Set up filebeat system module
sudo systemctl daemon-reload
sudo systemctl enable filebeat
sudo filebeat modules enable system
sudo filebeat setup

# Start up kibana
sudo systemctl restart filebeat.service
