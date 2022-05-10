#!/usr/bin/expect -f

set elastic_pass [lindex $argv 0];

set timeout -1
spawn sudo /usr/share/elasticsearch/bin/elasticsearch-setup-passwords interactive

expect -ex "Please confirm that you would like to continue \[y/N\]"
send -- "y\r"

expect -ex "Enter password for \[elastic\]: "
send -- "${elastic_pass}\r"

expect -ex "Reenter password for \[elastic\]: "
send -- "${elastic_pass}\r"

expect -ex "Enter password for \[apm_system\]: "
send -- "${elastic_pass}\r"

expect -ex "Reenter password for \[apm_system\]: "
send -- "${elastic_pass}\r"

expect -ex "Enter password for \[kibana\]: "
send -- "${elastic_pass}\r"

expect -ex "Reenter password for \[kibana\]: "
send -- "${elastic_pass}\r"

expect -ex "Enter password for \[logstash_system\]: "
send -- "${elastic_pass}\r"

expect -ex "Reenter password for \[logstash_system\]: "
send -- "${elastic_pass}\r"

expect -ex "Enter password for \[beats_system\]: "
send -- "${elastic_pass}\r"

expect -ex "Reenter password for \[beats_system\]: "
send -- "${elastic_pass}\r"

expect -ex "Enter password for \[remote_monitoring_user\]: "
send -- "${elastic_pass}\r"

expect -ex "Reenter password for \[remote_monitoring_user\]: "
send -- "${elastic_pass}\r"

expect eof
