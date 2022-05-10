# Sample Logstash configuration for creating a simple
# Beats -> Logstash -> Elasticsearch pipeline.

input {
  beats {
    port => ${logstash_port}
  }
}

output {
  elasticsearch {
    hosts => ["https://${elastic_host}:${elastic_port}"]
    index => "%%{[@metadata][beat]}-%%{[@metadata][version]}-%%{+YYYY.MM.dd}"
    #manage_template => false
    #ilm_enabled => true
    #ilm_pattern => "000001"
    ssl => true
    ssl_certificate_verification => true
    cacert => "/etc/logstash/certs/logstash-ca.cert"
    user => "elastic"
    password => "Koala!65"
  }
}
