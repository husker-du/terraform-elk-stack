#!/bin/bash -x

# Get the command line arguments
cluster_name=$1
user_name=$2
ssh_private_key_file=$3
elk_version=$4
node_name=$5
nodes_private_ips=$6 # string of comma separated ips
ca_pass=$7
cert_pass=$8
elastic_pwd=$9

ca_file=/etc/elasticsearch/certs/ca
tmp_ca_file=/tmp/ca
cert_file=/etc/elasticsearch/certs/${node_name}
logstash_cert_file=/etc/elasticsearch/certs/logstash

# Install elasticsearch
sudo yum update -y >/dev/null && sudo yum install vim-enhanced expect -y
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
sudo rpm -i https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${elk_version}-x86_64.rpm

# Move the elasticsearch configuration file to its location
sudo chown root:elasticsearch ./elasticsearch.yml
sudo mv ./elasticsearch.yml /etc/elasticsearch/

sudo mkdir /etc/elasticsearch/certs

if [[ ${node_name} =~ 'master' ]]; then
  # Create the CA
  [[ -f "${ca_file}" ]] && sudo rm ${ca_file} || :
  sudo /usr/share/elasticsearch/bin/elasticsearch-certutil ca --out ${ca_file} --pass ${ca_pass}
  # Copy the root CA to all the elasticsearch nodes
  chmod 400 ${ssh_private_key_file}
  # Copy the certificate to all the nodes in the cluster
  for es_node_ip in $(echo ${nodes_private_ips} | sed "s/,/ /g"); do 
    sudo scp -i ${ssh_private_key_file} -o StrictHostKeyChecking=no ${ca_file} ${user_name}@${es_node_ip}:/tmp
  done
fi

# Wait for the root CA to be copied in the temporal directoy
set +x
declare -i count=0
declare -i timeout=30
while [ ! -f "${tmp_ca_file}" ] || [ ${count} < ${timeout} ]; do
  sleep 1
  count=${count}+1
  echo "waiting ${count} secs..."
done
set -x

# Move the CA to the certs directory
sudo mv ${tmp_ca_file} ${ca_file}
sudo chown root:elasticsearch ${ca_file}

# Generate the certificates
[[ -f "${cert_file}" ]] && sudo rm ${cert_file} || :
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert \
    --ca ${ca_file} \
    --ca-pass ${ca_pass} \
    --name ${node_name} \
    --dns $(hostname) \
    --ip $(hostname -I | awk '{print $1}') \
    --out ${cert_file} \
    --pass ${cert_pass}
sudo chmod 640 ${cert_file}

# Add certificate password to the keystore and truststore
echo "${cert_pass}" | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore add -xf xpack.security.transport.ssl.keystore.secure_password
echo "${cert_pass}" | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore add -xf xpack.security.transport.ssl.truststore.secure_password

echo "${cert_pass}" | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore add -xf xpack.security.http.ssl.keystore.secure_password
echo "${cert_pass}" | sudo /usr/share/elasticsearch/bin/elasticsearch-keystore add -xf xpack.security.http.ssl.truststore.secure_password

# Make elasticsearch to be started at boot
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch.service

# Start up elasticsearch
sudo systemctl restart elasticsearch.service
