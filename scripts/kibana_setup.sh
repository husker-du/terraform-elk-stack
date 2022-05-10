#!/bin/bash -x

# Command line arguments
elk_version=$1

# Install kibana
sudo yum update -y >/dev/null && sudo yum install vim-enhanced -y
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
sudo rpm -i https://artifacts.elastic.co/downloads/kibana/kibana-${elk_version}-x86_64.rpm

# Set up kibana configuration
sudo mv kibana.yml /etc/kibana/
sudo chown root:root /etc/kibana/kibana.yml

# Start up kibana
sudo systemctl daemon-reload
sudo systemctl enable kibana
sudo systemctl restart kibana
