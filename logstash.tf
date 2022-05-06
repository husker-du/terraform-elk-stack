# ---------------------------------------------------------------------------------------------------------------------
# Create a security group to control what traffic can go in and out of the logstash instance
# --------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "logstash_sg" {
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
    from_port   = 5044
    to_port     = 5044
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
    Name = "logstash_sg"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 instance for logstash
# --------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "logstash" {
  depends_on                  = [null_resource.install_kibana]
  ami                         = data.aws_ami.rhel_8_5.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.logstash_sg.id]
  key_name                    = aws_key_pair.ssh.key_name
  associate_public_ip_address = true
  tags = {
    Name = "logstash"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Copy the 'logstash.yml' file to the logstash instance
# --------------------------------------------------------------------------------------------------------------------
data "template_file" "init_logstash" {
  depends_on = [aws_instance.logstash]
  template   = file("${path.module}/templates/${var.elk_version}/logstash.conf.tpl")
  vars = {
    elastic_host  = aws_instance.elasticsearch_node["master-1"].private_ip
    elastic_port  = var.elastic_port
    logstash_port = var.logstash_port
  }
}

resource "null_resource" "move_logstash_file" {
  depends_on = [aws_instance.logstash]
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.logstash.public_ip
  }
  provisioner "file" {
    content     = data.template_file.init_logstash.rendered
    destination = "logstash.conf"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Set up and start up logstash
# --------------------------------------------------------------------------------------------------------------------
resource "null_resource" "install_logstash" {
  depends_on = [aws_instance.logstash]
  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(local_file.save_key_file.filename)
    host        = aws_instance.logstash.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y && sudo yum install java-1.8.0-openjdk vim-enhanced -y",
      "sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch",
      "sudo rpm -i https://artifacts.elastic.co/downloads/logstash/logstash-${var.elk_version}.rpm",
      "sudo mv logstash.conf /etc/logstash/conf.d/",
      "sudo chown root:root /etc/logstash/conf.d/logstash.conf",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable logstash",
      "sudo systemctl restart logstash"
    ]
  }
}