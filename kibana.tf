# ---------------------------------------------------------------------------------------------------------------------
# Create a security group to control what traffic can go in and out of the kibana instance
# --------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "kibana_sg" {
  name = "kibana-sg"
  ingress {
    description = "ingress rules"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  ingress {
    description = "ingress rules"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = var.kibana_port
    to_port     = var.kibana_port
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
    Name = "kibana-sg"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 instance for kibana
# --------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "kibana" {
  depends_on = [null_resource.start_elasticsearch]

  ami                         = data.aws_ami.rhel_8_5.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.kibana_sg.id]
  key_name                    = aws_key_pair.ssh.key_name
  associate_public_ip_address = true
  tags = {
    Name = "kibana"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the 'kibana.yml' file to the kibana instance
# --------------------------------------------------------------------------------------------------------------------
data "template_file" "init_kibana" {
  depends_on = [aws_instance.kibana]

  template = file("${path.module}/templates/${var.elk_version}/kibana.yml.tpl")
  vars = {
    elastic_host = aws_instance.elasticsearch_node["master-1"].private_ip
    elastic_port = var.elastic_port
    kibana_host  = aws_instance.kibana.private_ip
    kibana_port  = var.kibana_port
    kibana_pwd   = var.kibana_pwd
  }
}

resource "null_resource" "move_kibana_file" {
  depends_on = [aws_instance.kibana]

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.kibana.public_ip
  }
  provisioner "file" {
    content     = data.template_file.init_kibana.rendered
    destination = "kibana.yml"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up and start up kibana
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "install_kibana" {
  depends_on = [aws_instance.kibana, null_resource.move_kibana_file]

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.kibana.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y && yum install vim-enhanced -y",
      "sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch",
      "sudo rpm -i https://artifacts.elastic.co/downloads/kibana/kibana-${var.elk_version}-x86_64.rpm",
      "sudo mv kibana.yml /etc/kibana/",
      "sudo chown root:root /etc/kibana/kibana.yml",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable kibana",
      "sudo systemctl restart kibana"
    ]
  }
}