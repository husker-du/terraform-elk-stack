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
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the 'elasticsearch.yml' file to the cluster nodes
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "init_elasticsearch" {
  depends_on = [aws_instance.elasticsearch_node]

  for_each = aws_instance.elasticsearch_node

  template = file("${path.module}/templates/${var.elk_version}/elasticsearch.yml.tpl")
  vars = {
    cluster_name   = var.cluster_name
    node_name      = each.key
    master_host    = aws_instance.elasticsearch_node["master-1"].private_ip
    master_node    = "master-1"
    node_is_master = one(regexall("master", each.key)) != null ? true : false
    node_is_data   = one(regexall("data", each.key)) != null ? true : false
    node_is_ingest = one(regexall("master", each.key)) != null ? true : false
  }
}

resource "null_resource" "move_elasticsearch_file" {
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
    content     = data.template_file.init_elasticsearch[each.key].rendered
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
resource "null_resource" "start_elasticsearch" {
  depends_on = [null_resource.move_elasticsearch_file, null_resource.move_ssh_private_key_file]

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
    content     = file("${path.module}/scripts/init_elasticsearch_node.sh")
    destination = "/tmp/init_elasticsearch_node.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/init_elasticsearch_node.sh",
      "sudo /tmp/init_elasticsearch_node.sh ${var.cluster_name} ${var.user_name} ${local_file.save_key_file.filename} ${var.elk_version} ${each.key} ${join(",", values(aws_instance.elasticsearch_node).*.private_ip)}",
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
