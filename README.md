# tf-aws-infra

Commands to run the infra
cd src
cd terraform
terraform apply -var-file="dev.tfvars"

Please include a dev.tfvars file in the /src/terraform path

SSL 

This terraform code sets up the infrastructure on AWS which includes a VPC, 3 private and 3 public subnets

# Key features:

- All the resources and the data is encrypted with KMS key
- Access to the resources are restricted by ingress and egress rules
- Custom policies are made for every resource in order to prevent external excess
