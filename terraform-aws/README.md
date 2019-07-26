# AWS deployment

## Create the AMIs with Packer

Go to the packer folder and see the README there. Once you have the AMI ID, return here and continue with the next steps.

## Create key-pair

```bash
aws ec2 create-key-pair --key-name presto --query 'KeyMaterial' --output text > presto.pem
```

## VPC

The Presto cluster is going to be deployed in a single subnet, within a single VPC, in a single availability zone. The idea behind this decision is to reduce latency and costs associated with transferring data between networks and AZs. Since Presto is usually used for non-mission critical parts of a system, this is usually acceptable.

Create a VPC or use an existing one, and get it. You will need the VPC ID we will use the available subnets within it. 

## Configurations

Edit `variables.tf` to specify the following:

* `aws_region` - the region where to launch the cluster in.
* `key_name` - the name of the key to use - that key needs to be handy so you can access the machines if needed.
* `vpc_id` - the ID of the VPC to launch the cluster in.
* `public_facing` - whether or not the coordinator node should be open to the internet. The default and the highly recommended value is `false`.
* `additional_security_groups` - here you add IDs for security groups you want to add to the coordinator load balancer so your clients (e.g. Redash, applications, etc) can access the coordinator for querying.
* `count_clients` - number of client nodes with Redash and Apache Superset installed, with configured admin user and datasource pointing to the Presto cluster. Default is `0`.

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

coordinator-lb-dns = internal-test-presto-lb-963348710.eu-central-1.elb.amazonaws.com
```

Note `coordinator-lb-dns` - that's your entry point to the Presto cluster. All queries should go to that URL, and the Presto UI accessible at that address as well (port 8080). 

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