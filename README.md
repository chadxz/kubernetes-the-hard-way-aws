# kubernetes the hard way (on AWS)

Following [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) but
on AWS instead of GCP. Learning Terraform in the process.

### tools and environment
* https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-client-tools.md
* `brew install awscli` and setup default profile and credentials
* install Docker for Mac, which includes `kubectl` cli app
* `brew install cfssl`

### network and compute
* https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md
* create VPC with CIDR `10.240.0.0/24`
* create SG to allow all traffic within VPC tcp,udp,icmp
* create SG to allow tcp:22,tcp:6443,icmp from external
* provision 3 instances for control plane: controller-0/1/2, ip 10.240.0.10/11/12
* provision 3 instances for worker nodes: worker-0/1/2, ip 10.240.0.20/21/22
* setup SSH to hosts

I also performed the following:

* setup a versioning-enabled s3 bucket for terraform state
* setup a DynamoDB table with LockID (string) partition key for terraform state
* Created an IAM role to assign AmazonSSMManagedInstanceCore policy to instances
  to use Session Manager instead of SSH
    * SSM also requires instance to be able to access its AWS public zone APIs,
      so we had to setup an internet gateway and assign instances public ipv4 ip addresses.
      This could have also been accomplished using a NAT gateway without assigning
      public ipv4 addresses, but those cost $.
* installed session manager plugin for aws-cli to support the `aws ssm start-session` command
* One main point here is I didn't expose SSH ports, and am instead using AWS SSM for access.
  An SSH key must still be provisioned to the server though to use SSH/SCP tooling, but the access control
  is done using IAM instead of interface security groups or subnet network access control lists.

## Provisioning a CA and Generating TLS Certificates
* https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
* All the commands used for this, and sending them to the corresponding hosts, are in the script
  [certificates/gen-certificates.sh](certificates/gen-certificates.sh)
  * This shell script would be better as a Makefile, so it doesn't constantly regenerate the certificates
    over and over. Can revisit that if need be. Using `scp` to copy the certificates would be better
    as an Ansible script as well.
