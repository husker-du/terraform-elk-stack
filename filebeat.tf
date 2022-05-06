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

# ---------------------------------------------------------------------------------------------------------------------
# EC2 instance for filebeat
# --------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "filebeat" {
  depends_on                  = [null_resource.install_kibana]
  ami                         = data.aws_ami.rhel_8_5.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.filebeat_sg.id]
  key_name                    = aws_key_pair.ssh.key_name
  associate_public_ip_address = true
  tags = {
    Name = "filebeat"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the 'filebeat.yml' file to the filebeat instance
# --------------------------------------------------------------------------------------------------------------------
data "template_file" "init_filebeat" {
  depends_on = [aws_instance.filebeat, aws_instance.logstash]
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

resource "null_resource" "move_filebeat_file" {
  depends_on = [aws_instance.filebeat]
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.filebeat.public_ip
  }
  provisioner "file" {
    content     = data.template_file.init_filebeat.rendered
    destination = "filebeat.yml"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the 'metricbeat.yml' file to the filebeat instance
# --------------------------------------------------------------------------------------------------------------------
data "template_file" "init_metricbeat" {
  depends_on = [aws_instance.filebeat]
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

resource "null_resource" "move_metricbeat_file" {
  depends_on = [aws_instance.filebeat]
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.filebeat.public_ip
  }
  provisioner "file" {
    content     = data.template_file.init_metricbeat.rendered
    destination = "metricbeat.yml"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up and start up filebeat
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "install_filebeat" {
  depends_on = [null_resource.move_filebeat_file]
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.filebeat.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y && yum install vim-enhanced -y",
      "sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch",
      "sudo rpm -i https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${var.elk_version}-x86_64.rpm",
      "sudo mv filebeat.yml /etc/filebeat/",
      "sudo chown root:root /etc/filebeat/filebeat.yml",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable filebeat",
      "sudo filebeat modules enable system",
      "sudo filebeat setup",
      "sudo systemctl restart filebeat.service",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up and start up metricbeat
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "install_metricbeat" {
  depends_on = [null_resource.move_metricbeat_file]
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.filebeat.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch",
      "sudo rpm -i https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-${var.elk_version}-x86_64.rpm",
      "sudo mv metricbeat.yml /etc/metricbeat/",
      "sudo chown root:root /etc/metricbeat/metricbeat.yml",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable metricbeat",
      "sudo metricbeat modules enable system",
      "sudo metricbeat setup",
      "sudo systemctl restart metricbeat.service",
    ]
  }
}