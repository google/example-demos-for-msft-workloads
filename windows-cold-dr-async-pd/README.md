# Windows Cold DR using PD Async Replication

This code will facilitate the creation of 10 VMs that will auto-join a domain, a DR failover, and a failback.  The domain controller was built manually to support this solution, and should be created first if wishing to test with one.  This repo contains the code to build the secondary boot disk and establish the asyncrhonous replication for the manually created domain controller.  This solution uses [Persistent Disk Asynchronous Replication](https://cloud.google.com/compute/docs/disks/async-pd/about), and requires the use of an instance template to faciliate the creation of Windows servers.  A sample gcloud command is included in setup\templatefiles.

VPC networks, subnets, peerings, and Cloud DNS configurations are not provided with this code at this time, but can be referenced in the architecture diagram below.

Locals are used in each folder for ease of manipulation.  These can be extracted into CSV files for customization and use within your own organiziation.  For this demo, the locals contain the server names and some other information needed for DR and failback.  Please review the contents and modify, if desired.

### Assumptions for this repo
 - This is designed for region to region failover -- if a single zone is having issues, there might be better options.
 - As of 01/2023, managed services like Cloud SQL and networking products like Private Service Connect have not been tested.
 - During a DR event, it is your responsibility to ensure no connectivity is flowing into the production environment. This solution does not cover any move of external IP addresses or load balancing, nor egress from the DR VPC.
   - Public IPs may or may not change depending on the presence and specifics of web-facing apps, internet access specifics, security services, etc.
 - This was designed with Shared VPC use in mind.  It is your responsibility to ensure all permissions and subnets are assigned pre-DR.
 - Each production region will require its own Shared VPC due to the VPC Peering requirement.  You may opt for a single DR Shared VPC, but could also have mulitple DR Shared VPCs to mirror production.
 - The Cloud Routers and Cloud NAT are there for outbound internet access and are optional components.
 - There are service projects for production, service projects for DR, and separate Shared VPCs to accomodate each environment ***using the same IP range***.  This solution requires an architecture similar to this (on premises components fully optional):

![Windows Cold DR with PD Async Replication](./images/Windows%20Cold%20DR%20Architecture.png)

## Setup Folder
Contains code to spin up 10 Windows Server servers and join them to a domain, create DR boot disks for all 10 and the domain controller (if using) in the DR region, and create the asynchronous replication pairs for all disks.  The code is written to preserve IP addresses.

## DR Folder
Contains code to spin up DR servers using the replicated disks and IP addresses from production (including the domain controller), create failback boot disks in the productino region, and create the failback async replication pairs for all disks.  The IP addresses are preserved for failback.

## Failback Folder
Contains code to spin up failback/production servers using the replicated disks and IP addresses from DR, and includes code to recreate DR boot disks and async replication pairs to prepare for the next DR event.

# How to Setup the Environment
As of 01/2024, this repo does not contain the code necessary to build out an entire environment.  Some general steps and guidelines are provided here in order to help with this demo.

> [!NOTE]
> These instructions assume that you are building out the same environment as shown in the Architecture diagram

### Organization Requirements

This demo uses a [Shared VPC](https://cloud.google.com/vpc/docs/shared-vpc#shared_vpc_host_project_and_service_project_associations) architecture which requires the use of a Google Cloud Organization. 

### IAM Requirements

The following IAM Roles are required for this demo
1. [Project Creator](https://cloud.google.com/iam/docs/understanding-roles#resourcemanager.projectCreator)
2. [Project Deleter](https://cloud.google.com/iam/docs/understanding-roles#resourcemanager.projectDeleter)
2. [Billing Account User](https://cloud.google.com/billing/docs/how-to/billing-access#billing.user) for the Billing Account in your Organization
3. [Compute Admin](https://cloud.google.com/iam/docs/understanding-roles#compute.admin)
4. [Compute Shared VPC Admin](https://cloud.google.com/iam/docs/understanding-roles#compute.xpnAdmin)

### Building The Environment
1. Create three (3) projects in Google Cloud
    - Project #1: Shared VPC Host Project
    - Project #2: Service Project for Production
    - Project #3: Service Project for DR
2. Create three (3) VPCs in the **Shared VPC Host Project**
    - VPC #1: Shared Services VPC as `shared-svcs` 
    - VPC #2: Production VPC as `app-prod` 
    - VPC #3: DR VPC as `app-dr`
3. In the `shared-svcs` VPC, create two (2) subnets
    - Shared Services Subnet #1: `sn-shrdsvcs-us-east4` with IP range `10.0.0.0/21`
    - Shared Services Subnet #2: `sn-shrdsvcs-us-central1` with IP range `10.20.0.0/21`
4. In the `app-prod` VPC create one (1) subnet
    - Production Subnet #1: `prod-app-us-east4` with IP range `10.1.0.0/21`
5. In the `app-dr` VPC create one (1) subnet
    - DR Subnet #1: `dr-app-us-central1` with IP range `10.1.0.0/21`
      **_Note_** The IP range in DR is the same as Production
6. Create a [VPC Peering configuration](https://cloud.google.com/vpc/docs/using-vpc-peering#creating_a_peering_configuration) between the `shared-svcs` VPC and `app-prod` VPC
    - You will also need to create a VPC Peering from the `app-prod` VPC to the `shared-svcs` VPC
    - **_Optional_** You can pre-stage the peering from the `app-dr` VPC to the `shared-svcs` VPC to save time in a DR event, but it is not required at this time.
7. [Enable the Shared VPC Host Project](https://cloud.google.com/vpc/docs/provisioning-shared-vpc#enable-shared-vpc-host)
8. [Attach the Production and DR Service Projects](https://cloud.google.com/vpc/docs/provisioning-shared-vpc#create-shared)
    - Ensure that you share `prod-app-us-east4` with the Production Project only
    - Ensure that you share `dr-app-us-central1` with the DR Project only
9. In the Shared VPC Host Project, configure Cloud DNS per [best practices](https://cloud.google.com/compute/docs/instances/windows/best-practices) to support your domain and Active Directory.  You will need a forwarding zone for your domain associated with Shared Services, and DNS Peering from Shared Services to the other VPCs to support domain resolution.
    - More info on Cloud DNS can be found [here](https://cloud.google.com/dns/docs/best-practices).
10. **_Optional_** If you wish to test with an Active Directory Domain, you can set up a [Domain Controller](https://cloud.google.com/architecture/deploy-an-active-directory-forest-on-compute-engine#deploy_the_active_directory_forest) in the Production Project using the `app-prod` VPC

# Building The Test Servers

> [!IMPORTANT]
> If you are not using a Domain Controller to test, please comment out lines `26-32` in `prod-async-rep.tf` and lines `54-87` in `prod-sec-boot-disks.tf`

1. [Create an Instance template](https://cloud.google.com/compute/docs/instance-templates/create-instance-templates) in the Service Project for Production
    - A sample `gcloud` command has been provided in the **/setup/templatefiles** folder for your convenience
2. Navigate to the **/setup** folder and populate the `terraform.tfvars` file with your environment values
    - If you are using a Domain Controller, navigate to the **/setup/templatefiles** folder and update `ad-join.tpl` with your values. 
3. While in the **/setup** directory run the terraform commands
    - `terraform init` 
    - `terraform plan out tf.out` (there should be 42 resources to add)
    - `terraform apply tf.out`  

   The default configuration will deploy 
    - Ten (10) Windows Servers (Domain joined if configured) 
    - Secondary boot disks in the DR Project
    - Async replication to DR

> [!NOTE]
> Please allow 15-20 minutes for initial replication to complete. If using your own systems with larger disks, initial replication time may be longer. The initial replication is complete when the `disk/async_replication/time_since_last_replication` metric is available in Cloud Monitoring.

4. Navigate to the **/dr** folder and update the `terraform.tfvars` file with repsective values to prepare for DR
5. While in the **/setup** directory run the terraform commands
    - `terraform init` 
    - `terraform plan out tf.out` (there should be 11 resources to add)
    - `terraform apply tf.out`  

# DR Failover

> [!IMPORTANT]
> If you are not using a Domain Controller to test, please comment out lines `26-32` in `stage-failback-async-rep.tf` and lines `18, 54-88` in `stage-failback-async-boot-disks.tf`

1. Simulate a DR event (e.g. shut down the production VMs)
2. Navigate to the \setup folder and rename `prod-async-rep.tf` to `prod-async-rep.tf.dr`
3. Run `terraform plan` to check for errors (should see 11 resources to destroy), then `terraform apply` to stop asynchronous replication
4. In the console, sever VPC peering from shared-svcs to production, and establish VPC peering from shared-svcs to DR
5. Navigate to the \dr folder
6. Run `terraform init` and `terraform plan` to check for errors (should see 11 resources to add), then `terraform apply` to recover the VMs in the DR region using the replicated disks from production ()
7. Validate all servers and applications are back online and connected to the domain
8. Delete the old production VMs and their disks
9. Rename `stage-failback-async-boot-disks.tf.dr` to `stage-failback-async-boot-disks.tf` and `stage-failback-async-rep.tf.dr` to `stage-failback-async-rep.tf`
10. Run `terraform plan` to check for errors (should see 22 resources to add), then `terraform apply` to create new boot disks in the production region for failback, and the associated async replication pairs from DR
    - Allow 15-20 minutes for initial replication to complete
    - If using your own systems with larger disks, initial replication time may be longer. The initial replication is complete when the disk/async_replication/time_since_last_replication metric is available in Cloud Monitoring.
11. Navigate to the \failback folder and update the .tfvars files with repsective values to prepare for production failback
12. Run `terraform init` and `terraform plan` (should see 11 resources to add) and fix any problems to speed up failback

# Production Failback
***If not using a domain controller, you will need to comment out lines 26-32 in restage-dr-async-rep.tf and lines 18, 54 to 88 in dr-east-sec-boot-disks.tf.***

1. Shut down DR VMs
2. Navigate to the \dr folder
3. Rename `stage-failback-async-rep.tf` to `stage-failback-async-rep.tf.dr`
4. Run `terraform plan` to check for errors (should see 11 resources to destroy), then `terraform apply` to stop replication
5. In the console, sever VPC peering from shared-svcs to DR, and establish VPC peering from shared-svcs to production
6. Navigate to the \failback folder
7. Run `terraform plan` to check for errors (should see 11 resources to add), then `terraform apply` to recover your VMs in the original production region using the replicated disks from DR
8. Validate all servers and applications are back online and connected to the domain
9. Delete the old DR VMs and their disks
10. Rename `restage-dr-async-boot-disks.tf.failback` to `restage-dr-async-boot-disks.tf` and `restage-dr-async-rep.tf.failback` to `restage-dr-async-rep.tf`
11. Run `terraform plan` to check for errors (should see 22 resources to add), then `terraform apply` to create new boot disks in the DR region, and the associated async replication pairs to prepare for the next DR event
    - Allow 15-20 minutes for initial replication to complete
    - If using your own systems with larger disks, initial replication time may be longer. The initial replication is complete when the disk/async_replication/time_since_last_replication metric is available in Cloud Monitoring.

# Future DR and Failback Events
In the case of future DR events, you would follow the steps in the _DR Failover_ section, with the following exceptions:

2. Navigate to the ~~\setup~~ \failback folder and rename ~~`prod-async-rep.tf` to `prod-async-rep.tf.dr`~~ `restage-dr-async-rep.tf` to `restage-dr-async-rep.tf.failback`
9. Rename ~~`stage-failback-async-boot-disks.tf.dr` to `stage-failback-async-boot-disks.tf` and~~ `stage-failback-async-rep.tf.dr` to `stage-failback-async-rep.tf`

And similary, to failback, you would follow the steps in the _Production Failback_ section, with the following exceptions:

10. Rename ~~`restage-dr-async-boot-disks.tf.failback` to `restage-dr-async-boot-disks.tf` and~~ `restage-dr-async-rep.tf.failback` to `restage-dr-async-rep.tf`