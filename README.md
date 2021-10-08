# kubernetes the hard way (on AWS)

Following [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) but
on AWS instead of GCP. Learning Terraform in the process.

### tools and environment
* [https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-client-tools.md]()
* `brew install awscli` and setup default profile and credentials
* install Docker for Mac, which includes `kubectl` cli app
* `brew install cfssl`

### network and compute
* [https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md]()
* create VPC with CIDR `10.240.0.0/24`
* create SG to allow all traffic within VPC tcp,udp,icmp
* create SG to allow tcp:22,tcp:6443,icmp from external
* provision 3 instances for control plane: controller-0/1/2, ip 10.240.0.10/11/12
* provision 3 instances for worker nodes: worker-0/1/2, ip 10.240.0.20/21/22
* setup SSH to hosts