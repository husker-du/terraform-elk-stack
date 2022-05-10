output "elastic_public_ips" {
  #value = values(aws_instance.elasticsearch_node).*.public_ip
  value = { for name, node in aws_instance.elasticsearch_node : name => node.public_ip }
}

output "elastic_private_ips" {
  #value = values(aws_instance.elasticsearch_node).*.public_ip
  value = { for name, node in aws_instance.elasticsearch_node : name => node.private_ip }
}

output "elastic_urls" {
  value = formatlist("http://%s:%d", values(aws_instance.elasticsearch_node).*.public_dns, var.elastic_port)
}

output "kibana_url" {
  value = "http://${aws_instance.kibana.public_dns}:${var.kibana_port}"
}

output "logstash_url" {
  value = "http://${aws_instance.logstash.public_dns}:${var.logstash_port}"
}

output "ssh_connections" {
  value = ({ for instance in flatten([values(aws_instance.elasticsearch_node), aws_instance.kibana, aws_instance.logstash, aws_instance.filebeat]) : 
      instance.tags.Name => format("ssh -i .ssh/%s.pem %s@%s", var.key_name, var.user_name, instance.public_dns) })
}
