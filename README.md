# TerraPhish

GoPhish on AWS implementated using Terraform. 

The configuration creates an EC2 instance with Ubuntu 18.04 LTS_x64 ami (you can change this if you want to, however it may break some functionality). DNS records for mail reputation such as SPF and DMARC are created automaticaly, except DKIM TXT record (discussed below). Other configurations include:
* LetsEncrypt: Automatically fetches a certificate and configures it to use with goPhish
* Postfix: For SMTP relay
* DKIM: To sign outbound emails



**Variables**

Change the values in terraform.tfvars file before using. 

Variable Name | Comments
--------------| ----------------
aws_access_key| Your AWS access key
aws_secret_key| Your AWS secret key
domain_name | The domain name you control
key_path | Path to your private key, which should be in PEM encoded format (OpenSSH). PPK keys will not work.
key_name | Name of the key pair within your AWS account. Create one before using.
dkim_value | DKIM Value which will later be inserted as a DNS TXT record, in YYYYMM format. 

Create a key pair in AWS and change the key name on line 39 in master.tf to your keypair name. 

**Usage**

1. terraform init
1. terraform plan
1. terraform apply


**Important Notes**

The Terraform script creates three individual security groups, for SSH, TLS, and HTTP which is required for certbot HTTP challenge. You can remove the allow_http security group once the setup is done and if you dont intend to use it. 

It is also recommended to create a separate IAM role (administrator privileges recommended) to use for this setup. 

If your domain is from a different registrar, you would need to change the nameservers there to AWS' nameservers. 

Lastly, the DKIM value to be inserted as a TXT record in your DNS settings will be generated when the script finishes execution. The value will be stored under /opt/DKIM/$dkim_value.txt (defined as a variable above). AWS doesn't allow the entire value to be inserted as is, so you would have to break that into multiple parts using quotes ("). 

Example: YYYYMM._domainkey.example.com.         "v=DKIM1; h=sha256; k=rsa; s=email; p=XXXXXXXXXXXXXXXXXXXXXXXXXXXX" "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX""XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

**To do**

1. Implement some AWS terraform best practices. 
1. Figure out a way to set DKIM record automatically. (local-exec ?)
