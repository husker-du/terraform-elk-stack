#!/bin/bash -x

# Get the command line arguments
cluster_name=$1
user_name=$2
ssh_private_key_file=$3
elk_version=$4
node_name=$5
nodes_private_ips=$6 # string of comma separated ips

cert_file=/etc/elasticsearch/certs/${cluster_name}
tmp_cert_file=/tmp/${cluster_name}

# Install elasticsearch
sudo yum update -y && yum install vim-enhanced -y
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
sudo rpm -i https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${elk_version}-x86_64.rpm

# Move the elasticsearch configuration file to its location
sudo mv ./elasticsearch.yml /etc/elasticsearch/

# Reduce the default JVM heap memory settings in master node to allocate kibana in that node
# if [[ ${node_name} =~ 'master' ]]; then
#   sudo sed -i 's@-Xms1g@-Xms768m@g' /etc/elasticsearch/jvm.options
#   sudo sed -i 's@-Xmx1g@-Xmx768m@g' /etc/elasticsearch/jvm.options
# fi

# Put the same certificate in all the cluster nodes
sudo mkdir /etc/elasticsearch/certs
if [[ ${node_name} =~ 'master' ]]; then
  # Generate the certificate in the master node
  sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert --name ${cluster_name} --out $tmp_cert_file --pass ''
  sudo chown ${user_name}:${user_name} ${tmp_cert_file}
  chmod 400 ${ssh_private_key_file}
  # Copy the certificate to all the nodes in the cluster
  for ip in $(echo ${nodes_private_ips} | sed "s/,/ /g"); do 
    sudo scp -i ${ssh_private_key_file} -o StrictHostKeyChecking=no ${tmp_cert_file} ${user_name}@${ip}:/tmp
  done
fi

# Wait for the certificates to be copied in the temporal directory
set +x
declare -i count=0
declare -i timeout=30
while [ ! -f "${tmp_cert_file}" ] || [ ${count} < ${timeout} ]; do
  sleep 1
  count=${count}+1
  echo "count: ${count}"
done
set -x

# Move the certificates to the certs directory
sudo mv ${tmp_cert_file} ${cert_file}
sudo chmod 640 ${cert_file}
sudo chown $user_name:elasticsearch ${cert_file}

# Make elasticsearch to be started at boot
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch.service

# Start up elasticsearch
sudo systemctl restart elasticsearch.service
