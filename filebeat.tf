# ---------------------------------------------------------------------------------------------------------------------
# EC2 instance for filebeat
# --------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "filebeat" {
  ami                         = data.aws_ami.rhel_8_5.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.filebeat_sg.id]
  key_name                    = aws_key_pair.ssh.key_name
  associate_public_ip_address = true
  tags = {
    Name = "filebeat"
    Cluster = "elk"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the 'filebeat.yml' file to the filebeat instance
# --------------------------------------------------------------------------------------------------------------------
data "template_file" "filebeat_conf" {
  template   = file("${path.module}/templates/${var.elk_version}/filebeat.yml.tpl")
  vars = {
    elastic_host  = aws_instance.elasticsearch_node["master-1"].private_ip
    elastic_port  = var.elastic_port
    elastic_pwd   = var.elastic_pwd
    kibana_host   = aws_instance.kibana.private_ip
    kibana_port   = var.kibana_port
    logstash_host = aws_instance.logstash.private_ip
    logstash_port = var.logstash_port
    path_config   = "$${path.config}"
  }
}

resource "null_resource" "move_filebeat_conf" {
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.filebeat.public_ip
  }
  provisioner "file" {
    content     = data.template_file.filebeat_conf.rendered
    destination = "filebeat.yml"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the 'metricbeat.yml' file to the filebeat instance
# --------------------------------------------------------------------------------------------------------------------
data "template_file" "metricbeat_conf" {
  template   = file("${path.module}/templates/${var.elk_version}/metricbeat.yml.tpl")
  vars = {
    kibana_host   = aws_instance.kibana.private_ip
    kibana_port   = var.kibana_port
    elastic_host  = aws_instance.elasticsearch_node["master-1"].private_ip
    elastic_port  = var.elastic_port
    elastic_pwd   = var.elastic_pwd
    logstash_host = aws_instance.logstash.private_ip
    logstash_port = var.logstash_port
    path_config   = "$${path.config}"
  }
}

resource "null_resource" "move_metricbeat_conf" {
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.filebeat.public_ip
  }
  provisioner "file" {
    content     = data.template_file.metricbeat_conf.rendered
    destination = "metricbeat.yml"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up and start up filebeat
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "filebeat_setup" {
  depends_on = [
    null_resource.move_filebeat_conf
  ]
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.filebeat.public_ip
  }
  provisioner "file" {
    content     = file("${path.module}/scripts/filebeat_setup.sh")
    destination = "/tmp/filebeat_setup.sh"
  }
  provisioner "remote-exec" {
    inline = [<<-EOF
      sudo chmod +x /tmp/filebeat_setup.sh
      sudo /tmp/filebeat_setup.sh \
          ${var.elk_version}
      EOF
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up and start up metricbeat
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "metricbeat_setup" {
  depends_on = [
    null_resource.move_metricbeat_conf,
    null_resource.elasticsearch_metricbeat_cert
  ]
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.filebeat.public_ip
  }
  provisioner "file" {
    content     = file("${path.module}/scripts/metricbeat_setup.sh")
    destination = "/tmp/metricbeat_setup.sh"
  }
  provisioner "remote-exec" {
    inline = [<<-EOF
      sudo chmod +x /tmp/metricbeat_setup.sh
      sudo /tmp/metricbeat_setup.sh \
          ${nonsensitive(var.metricbeat_pass)} \
          ${var.elk_version}
      EOF
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Create a security group to control what traffic can go in and out of the filebeat instance
# --------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "filebeat_sg" {
  name = "filebeat-sg"
  ingress {
    description = "ingress rules"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  egress {
    description = "egress rules"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  tags = {
    Name = "filebeat-sg"
  }
}
