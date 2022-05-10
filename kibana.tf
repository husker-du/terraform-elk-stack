# ---------------------------------------------------------------------------------------------------------------------
# EC2 instance for kibana
# --------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "kibana" {
  ami                         = data.aws_ami.rhel_8_5.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.kibana_sg.id]
  key_name                    = aws_key_pair.ssh.key_name
  associate_public_ip_address = true
  tags = {
    Name = "kibana"
    Cluster = "elk"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the 'kibana.yml' file to the kibana instance
# --------------------------------------------------------------------------------------------------------------------
data "template_file" "kibana_conf" {
  template = file("${path.module}/templates/${var.elk_version}/kibana.yml.tpl")
  vars = {
    elastic_host = aws_instance.elasticsearch_node["master-1"].private_ip
    elastic_port = var.elastic_port
    kibana_host  = aws_instance.kibana.private_ip
    kibana_port  = var.kibana_port
    kibana_pwd   = var.kibana_pwd
  }
}

resource "null_resource" "move_kibana_conf" {
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.kibana.public_ip
  }
  provisioner "file" {
    content     = data.template_file.kibana_conf.rendered
    destination = "kibana.yml"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up and start up kibana
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "kibana_setup" {
  depends_on = [
    null_resource.move_kibana_conf
  ]

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.kibana.public_ip
  }
  provisioner "file" {
    content     = file("${path.module}/scripts/kibana_setup.sh")
    destination = "/tmp/kibana_setup.sh"
  }
  provisioner "remote-exec" {
    inline = [<<-EOF
      sudo chmod +x /tmp/kibana_setup.sh
      sudo /tmp/kibana_setup.sh \
          ${var.elk_version}
      EOF
    ]
  }
}

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
