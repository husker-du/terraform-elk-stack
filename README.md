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

