# Exercise 01

This code deploys a ELK stack in AWS.
- Three **elasticsearch** nodes in three EC2 instances: 1 master and ingest node and 2 data nodes.
- A **kibana** server in an EC2 instance.
- A **logstash** server in an EC2 instance.
- A **filebeat** and a **metricbeat** data clients in an EC2 instance.

## Quick start

To deploy this module:

1. Install [Terraform](https://www.terraform.io/)

2. Open up `vars.tf`, set the environment variables specified at the top of the file, and fill in `default` values for 
   any variables in the "REQUIRED PARAMETERS" section.

3. Run `terraform init`

3. Run `terraform plan`

4. If the plan looks good, run `terraform apply`
   
5. To destroy the stack, rjn `terraform destroy`

## Create a role and a user with the kibana console
```
GET _cat/nodes?v
GET _cat/indices?v

POST _security/role/monitor
{
  "indices": [
    {
      "names": ["*"],
      "privileges": ["read", "monitor"]
    }
  ]
}
GET _security/role/monitor

POST _security/user/noc
{
  "roles": ["kibana_user", "monitoring_user", "monitor_user"],
  "full_name": "Network Operations Center",
  "email": "noc@company.com",
  "password": "Koala!65"
}
GET _security/user/noc
```

## Create roles and users
```
POST _security/role/monitor
{
  "indices": [
    {
      "names": ["*"],
      "privileges": ["read", "monitor"]
    }
  ]
}
GET _security/role/monitor

POST _security/user/noc
{
  "roles": ["kibana_user", "monitoring_user", "monitor_user"],
  "full_name": "Network Operations Center",
  "email": "noc@company.com",
  "password": "Koala!65"
}
GET _security/user/noc
```

## Create indices
``
GET _cat/indices?v

PUT my_first_index_1
{
  "aliases": {
    "my_first_index": {}
  },
  "mappings": {
    "properties": {
      "field_1": {
        "type": "keyword"
      },
      "field_2": {
        "properties": {
          "field_2_1": {
            "type": "integer"
          }
        }
      }
    }
  },
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1
  }
}
GET my_first_index_1
GET my_first_index

PUT my_first_index_2
{
  "aliases": {
    "my_first_index": {}
  },
  "mappings": {
    "properties": {
      "field_1": {
        "type": "keyword"
      },
      "field_2": {
        "properties": {
          "field_2_1": {
            "type": "integer"
          }
        }
      }
    }
  },
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1
  }
}

DELETE my_first_index_1
DELETE my_first_index_2

PUT bank
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1
  }
}

PUT shakespeare
{
  "mappings": {
    "properties": {
      "speaker": {
        "type": "keyword"
      },
      "play_name": {
        "type": "keyword"
      },
      "line_id": {
        "type": "integer"
      },
      "speech_number": {
        "type": "integer"
      }
    }
  },
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1
  }
}

PUT logs
{
  "mappings": {
    "properties": {
      "geo": {
        "properties": {
          "coordinates": {
            "type": "geo_point"
          }
        }
      }
    }
  },
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1
  }
}
```

In master-1 /etc/elasticsearch:
sudo su -

curl -O https://raw.githubusercontent.com/linuxacademy/content-elasticsearch-deep-dive/master/sample_data/accounts.json
curl -O https://raw.githubusercontent.com/linuxacademy/content-elasticsearch-deep-dive/master/sample_data/shakespeare.json
curl -O https://raw.githubusercontent.com/linuxacademy/content-elasticsearch-deep-dive/master/sample_data/logs.json

curl -u elastic:Koala\!65 -k -H 'Content-type: application/x-ndjson' -X POST https://localhost:9200/bank/_bulk --data-binary @accounts.json
curl -u elastic:Koala\!65 -k -H 'Content-type: application/x-ndjson' -X POST https://localhost:9200/shakespeare/_bulk --data-binary @shakespeare.json
curl -u elastic:Koala\!65 -k -H 'Content-type: application/x-ndjson' -X POST https://localhost:9200/logs/_bulk --data-binary @logs.json


POST bank/_refresh
POST shakespeare/_refresh
POST logs/_refresh

GET bank/_doc/0

PUT bank/_doc/1000
{
  "account_number": 1000,
  "balance": 2000000,
  "firstname": "Carlos",
  "lastname": "Tomás",
  "age": 47,
  "gender": "X",
  "address": "Avda. Benito Pérez Galdós 10",
  "employer": "Monom",
  "email": "ctomas@monom.ai",
  "city": "Alcalá de Henares",
  "state": "Madrid"
}


POST bank/_update/1000
{
  "doc": {
    "city": "Chicago",
    "state": "IL",
    "favorite_color": "green"
  }
}

DELETE bank/_doc/1000

GET _analyze
{
  "analyzer": "english",
  "text": "The QUICK brown Foxes jumped over the fence."
}

GET shakespeare/_search

GET shakespeare/_search
{
  "size": 100, 
  "query": {
    "match": {
      "text_entry": "King lord"
    }
  }
}

GET shakespeare/_search
{
  "query": {
    "term": {
      "text_entry.keyword": {
        "value": "The king, the king!"
      }
    }
  }
}

GET shakespeare/_search
{
  "query": {
    "match_phrase": {
      "text_entry": "My lord"
    }
  }
}

# average age
GET bank/_search
{
  "size": 0,
  "aggs": {
    "avg_age": {
      "avg": {
        "field": "age"
      }
    }
  }
}

# maximum age
GET bank/_search
{
  "size": 0,
  "aggs": {
    "max_age": {
      "max": {
        "field": "age"
      }
    }
  }
}

# minimum age
GET bank/_search
{
  "size": 0,
  "aggs": {
    "min_age": {
      "min": {
        "field": "age"
      }
    }
  }
}

# total balance of all the accounts
GET bank/_search
{
  "size": 0,
  "aggs": {
    "total_balance": {
      "sum": {
        "field": "balance"
      }
    }
  }
}

# number of accounts per state
GET bank/_search
{
  "size": 0, 
  "aggs": {
    "accounts_per_state": {
      "terms": {
        "field": "state.keyword",
        "size": 100
      }
    }
  }
}

# number of logs per day
GET logs/_search
{
  "size": 0, 
  "aggs": {
    "events_per_data": {
      "date_histogram": {
        "field": "@timestamp",
        "calendar_interval": "day"
      }
    }
  }
}

# number of cities per state accounts
GET bank/_search
{
  "size": 0, 
  "aggs": {
    "accounts_per_state": {
      "terms": {
        "field": "state.keyword",
        "size": 50
      },
      "aggs": {
        "cities_per_state": {
          "cardinality": {
            "field": "city.keyword"
          }
        }
      }
    }
  }
}
```