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

1. Create three projects in Google Cloud -- a Shared VPC host project, one "production" project, and one "DR" project
2. In the Shared VPC host project, create three VPCs -- one for shared services, one for production, and one for DR
3. Configure two subnets in Shared Services, one each in your designated production and DR regions
4. Configure one subnet in Production in your designated prod region.  Do not overlap IPs with Shared Services.
5. Configure one subnet in DR in your designated DR region.  Use the same IP CIDR block as you did for Production.
6. Configure the Shared VPC permissions -- any user testing this solution will need Network User access to the Production and DR subnets, as well as the ability to peer VPCs
7. Peer Shared Services with Production, and Production with Shared Services
  - You could also peer DR with Shared Services to speed things up later, but it's not required at this time
8. In the Shared VPC Host Project, configure Cloud DNS per [best practices](https://cloud.google.com/compute/docs/instances/windows/best-practices) to support your domain and Active Directory.  You will need a forwarding zone for your domain associated with Shared Services, and DNS Peering from Shared Services to the other VPCs to support domain resolution.
  - More info on Cloud DNS can be found [here](https://cloud.google.com/dns/docs/best-practices).
9. Set up optional Domain Controller on the Production VPC

# How to Setup the Test Servers
***As mentioned above, a domain controller can be used in testing.  If wishing to use one, please manually create one first, then proceed to the steps below.  If not using a domain controller, you will need to comment out lines 26-32 in prod-async-rep.tf and lines 54 to 87 in prod-sec-boot-disks.tf.***

1. Set up an instance template in the production project -- a sample gcloud command is located in \setup\templatefiles
2. Navigate to the \setup folder
3. Populate the .tfvars file with your values
4. Navigate to the templatefiles folder and update `ad-join.tpl` with your values (or use your own domain join script)
5. Navigate back to the \setup directory, and run `terraform init` and `terraform plan` to check for errors (should see 42 resources to add), then `terraform apply` to deploy 10 Windows Server servers and join them to your domain, create secondary boot disks in the DR project and zone, and establish the async replication pairs to DR
    - Allow 15-20 minutes for initial replication to complete
    - If using your own systems with larger disks, initial replication time may be longer. The initial replication is complete when the disk/async_replication/time_since_last_replication metric is available in Cloud Monitoring.
6. Navigate to the \dr folder and update the .tfvars files with repsective values to prepare for DR
7. Run `terraform init` and `terraform plan` (should see 11 resources to add) and fix any problems to speed up recovery during a DR event

# DR Failover
***If not using a domain controller, you will need to comment out lines 26-32 in stage-failback-async-rep.tf and lines 18, 54 to 88 in stage-failback-async-boot-disks.tf.***

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