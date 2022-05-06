output "elastic_public_ips" {
  #value = values(aws_instance.elasticsearch_node).*.public_ip
  value = { for name, node in aws_instance.elasticsearch_node : name => node.public_ip }
}

output "elastic_urls" {
  value = formatlist("http://%s:%d", values(aws_instance.elasticsearch_node).*.public_ip, var.elastic_port)
}

output "kibana_url" {
  value = "http://${aws_instance.kibana.public_ip}:${var.kibana_port}"
}
