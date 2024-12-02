# tf-aws-infra

Commands to run the infra
cd src
cd terraform
<!-- Create a dev.tfvars or demo.tfvars file for variable values -->
terraform apply -var-file="dev.tfvars"


SSL 

aws acm import-certificate \
    --certificate file://~/Documents/SSL/demo.siddumbre.me/certificate.crt \
    --private-key file://~/Documents/SSL/demo.siddumbre.me/private.key \
    --certificate-chain file://~/Documents/SSL/demo.siddumbre.me/ca_bundle.crt \
    --region 'us-east-1' \
    --profile 'demo'


aws elb modify-load-balancer-attributes \
    --load-balancer-name my-load-balancer \
    --listeners Protocol=HTTPS,LoadBalancerPort=443,InstancePort=80,SSLCertificateId=certificate-arn