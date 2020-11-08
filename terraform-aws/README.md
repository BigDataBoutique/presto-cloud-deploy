# AWS deployment

## Create the AMIs with Packer

Go to the packer folder and see the README there. Once you have the generated an
AMI for the presto instance and the prestoclient instance, return here and
continue with the next steps.

## Create key-pair

```bash
aws ec2 create-key-pair --key-name presto --query 'KeyMaterial' --output text > presto.pem
```

## VPC

The Presto cluster is going to be deployed in a single subnet, within a single VPC, in a single availability zone. The idea behind this decision is to reduce latency and costs associated with transferring data between networks and AZs. Since Presto is usually used for non-mission critical parts of a system, this is usually acceptable.

A load balancer is placed in front of the the Presto cluster and another in
front of the Presto clients. To create a load balancer you need to associate it
with two subnets of the same VPC in distinct availability zones, even if one of
the availability zones is never used.

Create a VPC or use an existing one. Make a list of least two subnet IDs in
distinct availability zones. The first subnet in the list will be used to deploy
the Presto cluster and related resources. The subsequent subnets will be used to
configure the load balancer.

## Configurations

The most important variables specified in `variables.tf` are the following:

* `aws_region` - the region in which to launch the cluster.
* `key_name` - the name of the key pair for root SSH access to the EC2 instance. You can use the one created earlier.
* `subnet_ids` - the IDs of the VPC to launch the cluster in, as described above.
* `public_facing` - whether or not the coordinator node should be open to the internet. The default and the highly recommended value is `false`.
* `additional_security_groups` - here you add IDs for security groups you want to add to the coordinator load balancer so your clients (e.g. Redash, applications, etc) can access the coordinator for querying.
* `count_clients` - number of client nodes with Redash and Apache Superset installed, with configured admin user and datasource pointing to the Presto cluster. Default is `0`.
* `clients_lb_subnets` - list of subnet IDs to attach to the clients load balancer. At least two subnets from different availability zones must be provided.

We recommend using `tfvars` file to override all variables and configurations,
see https://www.terraform.io/intro/getting-started/variables.html#from-a-file
for more details.

You must create at least one client to generate the credentials to access the Presto UI.

You can launch workers and spot-workers (workers which run on spot-instances).

There are some more configurations to notice (like machine sizes, memory allocation, etc) which we will document soon

### Cluster topology

Two modes of deployment are supported:

* Production deployment with a single coordinator node and a bunch of worker nodes (number of workers is configurable) 
* Single node mode - one node acting as both coordinator and worker

## Launch the cluster with Terraform

On first usage, you will need to execute `terraform init` to initialize the terraform providers used.

To deploy the cluster, or apply any changes to an existing cluster deployed using this project, run:

```bash
terraform plan
terraform apply
```

When terraform is done, you should see a lot of output ending with something like this:

```
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

The state of your infrastructure has been saved to the path
below. This state is required to modify and destroy your
infrastructure, so keep it safe. To inspect the complete state
use the `terraform show` command.

State path: terraform.tfstate

Outputs:

clients-admin-password = [
  "********",
]
clients-lb-dns = [
  "example-presto-client-lb-1234567890.eu-west-1.elb.amazonaws.com",
]
coordinator-lb-dns = [
  "example-presto-lb-1234567890.eu-west-1.elb.amazonaws.com",
]
```

Note `coordinator-lb-dns` - that's your entry point to the Presto cluster. All
queries should go to that URL, and the Presto UI accessible at that address as
well (port 8080).

To enter the UI you pass the `clients-admin-password` as the user name and don't
set a password.

### Look around

You can pull the list of instances by their state and role using aws-cli:

```bash
aws ec2 describe-instances --filters Name=instance-state-name,Values=running
aws ec2 describe-instances --filters Name=instance-state-name,Values=running,Name=tag:Role,Values=client
```

To login to one of the instances:

```bash
ssh -i presto.pem ubuntu@{public IP / DNS of the instance}
```
