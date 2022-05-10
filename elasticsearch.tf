# ---------------------------------------------------------------------------------------------------------------------
# Create elasticsearch cluster
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "elasticsearch_node" {
  for_each      = toset(var.node_names)
  ami           = data.aws_ami.rhel_8_5.id
  instance_type = var.instance_type

  key_name                    = aws_key_pair.ssh.key_name
  vpc_security_group_ids      = [aws_security_group.elasticsearch_node.id]
  associate_public_ip_address = true

  tags = {
    Name = "es-node-${each.value}"
    Cluster = "elk"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the 'elasticsearch.yml' file to the cluster nodes
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "elasticsearch_conf" {
  for_each = aws_instance.elasticsearch_node

  template = file("${path.module}/templates/${var.elk_version}/elasticsearch.yml.tpl")
  vars = {
    cluster_name   = var.cluster_name
    node_name      = each.key
    master_host    = aws_instance.elasticsearch_node["master-1"].private_ip
    master_node    = "master-1"
    node_is_master = one(regexall("master", each.key)) != null ? true : false
    node_is_data   = one(regexall("data", each.key)) != null ? true : false
    node_is_ingest = one(regexall("data", each.key)) != null ? true : false
  }
}

resource "null_resource" "move_elasticsearch_conf" {
  for_each = aws_instance.elasticsearch_node

  # Changes to an instance of the elasticsearch cluster requires re-provisioning
  triggers = {
    instance_id = each.value.id
  }

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = each.value.public_ip
  }

  provisioner "file" {
    content     = data.template_file.elasticsearch_conf[each.key].rendered
    destination = "elasticsearch.yml"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the SSH private key to the master-1 node of the elasticsearch cluster
# ---------------------------------------------------------------------------------------------------------------------
resource "null_resource" "move_ssh_private_key_file" {
  for_each = aws_instance.elasticsearch_node

  # Changes to an instance of the elasticsearch cluster requires re-provisioning
  triggers = {
    instance_id = each.value.id
  }

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = each.value.public_ip
  }

  provisioner "file" {
    content     = local_file.save_key_file.content
    destination = "/home/${var.user_name}/${local_file.save_key_file.filename}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up and start up the elasticsearch nodes
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "elasticsearch_setup_node" {
  for_each = aws_instance.elasticsearch_node

  depends_on = [
    null_resource.move_elasticsearch_conf, 
    null_resource.move_ssh_private_key_file
  ]

  # Changes to an instance of the elasticsearch cluster requires re-provisioning
  triggers = {
    instance_id = each.value.id
  }

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = each.value.public_ip
  }
  provisioner "file" {
    content     = file("${path.module}/scripts/elasticsearch_setup_node.sh")
    destination = "/tmp/elasticsearch_setup_node.sh"
  }
  provisioner "file" {
    content     = file("${path.module}/scripts/elasticsearch_setup_passwords.sh")
    destination = "/tmp/elasticsearch_setup_passwords.sh"
  }
  provisioner "remote-exec" {
    inline = [<<-EOF
      sudo chmod +x /tmp/elasticsearch_setup_node.sh
      sudo /tmp/elasticsearch_setup_node.sh \
          ${var.cluster_name} \
          ${var.user_name} \
          ${local_file.save_key_file.filename} \
          ${var.elk_version} \
          ${each.key} \
          ${join(",", values(aws_instance.elasticsearch_node).*.private_ip)} \
          ${nonsensitive(var.ca_pass)} \
          ${nonsensitive(var.cert_pass[each.key])} \
          ${nonsensitive(var.elastic_pwd)}
      if [[ ${each.key} =~ 'master' ]]; then
        sudo chmod +x /tmp/elasticsearch_setup_passwords.sh
        sudo /tmp/elasticsearch_setup_passwords.sh \
            ${nonsensitive(var.elastic_pwd)}
      fi
      EOF
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up logstash certificate
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "elasticsearch_logstash_cert" {
  depends_on = [ 
    null_resource.elasticsearch_setup_node["master-1"]
  ]

  # Changes to an instance of the elasticsearch cluster requires re-provisioning
  triggers = {
    instance_id = aws_instance.elasticsearch_node["master-1"].id
  }

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.elasticsearch_node["master-1"].public_ip
  }
  provisioner "file" {
    content     = file("${path.module}/scripts/elasticsearch_logstash_cert.sh")
    destination = "/tmp/elasticsearch_logstash_cert.sh"
  }
  provisioner "remote-exec" {
    inline = [<<-EOF
      sudo chmod +x /tmp/elasticsearch_logstash_cert.sh
      sudo /tmp/elasticsearch_logstash_cert.sh \
          "${aws_instance.logstash.private_dns}" \
          "${aws_instance.logstash.private_ip}" \
          "${nonsensitive(var.ca_pass)}" \
          "${nonsensitive(var.logstash_pass)}" \
          "${local_file.save_key_file.filename}" \
          "${var.user_name}"
      EOF
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up metric certificate
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "elasticsearch_metricbeat_cert" {
  depends_on = [ 
    null_resource.elasticsearch_setup_node["master-1"]
  ]

  # Changes to an instance of the elasticsearch cluster requires re-provisioning
  triggers = {
    instance_id = aws_instance.elasticsearch_node["master-1"].id
  }

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.elasticsearch_node["master-1"].public_ip
  }
  provisioner "file" {
    content     = file("${path.module}/scripts/elasticsearch_metricbeat_cert.sh")
    destination = "/tmp/elasticsearch_metricbeat_cert.sh"
  }
  provisioner "remote-exec" {
    inline = [<<-EOF
      sudo chmod +x /tmp/elasticsearch_metricbeat_cert.sh
      sudo /tmp/elasticsearch_metricbeat_cert.sh \
          "${aws_instance.filebeat.private_dns}" \
          "${aws_instance.filebeat.private_ip}" \
          "${nonsensitive(var.ca_pass)}" \
          "${nonsensitive(var.metricbeat_pass)}" \
          "${local_file.save_key_file.filename}" \
          "${var.user_name}"
      EOF
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Create a security group to control what traffic can go in and out of the elasticsearch cluster
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "elasticsearch_node" {
  name = "es-sg"

  tags = {
    Name = "es-sg"
  }
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  from_port         = var.elastic_port
  to_port           = var.elastic_port
  protocol          = "tcp"
  security_group_id = aws_security_group.elasticsearch_node.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_ssh_inbound" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.elasticsearch_node.id

  # To keep this example simple, we allow SSH requests from any IP. In real-world usage, you should lock this down
  # to just the IPs of trusted servers (e.g., your office IPs).
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_es_discover_inbound" {
  type              = "ingress"
  from_port         = 9300
  to_port           = 9300
  protocol          = "tcp"
  security_group_id = aws_security_group.elasticsearch_node.id

  # To keep this example simple, we allow SSH requests from any IP. In real-world usage, you should lock this down
  # to just the IPs of trusted servers (e.g., your office IPs).
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.elasticsearch_node.id
  cidr_blocks       = ["0.0.0.0/0"]
}
