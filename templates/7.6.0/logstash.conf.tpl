# Sample Logstash configuration for creating a simple
# Beats -> Logstash -> Elasticsearch pipeline.

input {
  beats {
    port => ${logstash_port}
  }
}

output {
  elasticsearch {
    hosts => ["http://${elastic_host}:${elastic_port}"]
    index => "%%{[@metadata][beat]}-%%{[@metadata][version]}-%%{+YYYY.MM.dd}"
    user => "elastic"
    password => "Koala!65"
  }
}
