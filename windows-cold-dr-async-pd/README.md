# Windows Cold DR using PD Async Replication

This code will facilitate the creation of 10 VMs, a DR failover, and a failback.  The Domain Controller was built manually to support this solution, but code is available for the secondary disk and replication.  This is not required unless you wish to test Domain Controller DR.

VPC networks, subnets, VPC peerings, and Cloud DNS configuration is not provided with this code at this time.

### Assumptions for this repo
 - This is designed for region to region failover -- if a single zone is having issues, there might be better options.
 - As of 12/12/2023, managed services like Cloud SQL and networking products like Private Service Connect have not been tested.
 - During a DR event, it is your responsibility to ensure no connectivity is flowing into the production environment. This solution does not cover any move of external IP addresses, or load balancing, etc.
   - Public IPs may or may not change depending on the presence and specifics of web-facing apps, internet access specifics, security services, etc.
 - This was designed with Shared VPC use in mind.  It is your responsibility to ensure all permissions and subnets are assigned pre-DR.
 - Each production region will require its own Shared VPC due to the VPC Peering requirement.  You may opt for a single DR Shared VPC, but could also have mulitple DR Shared VPCs to mirror production.
 - The Cloud Routers and Cloud NAT are there for outbound internet access and are optional components.
 - There are service projects for production, service projects for DR, and separate Shared VPCs to accomodate each environment ***using the same IP range***.  This solution requires an architecture similar to this (on premises components fully optional):

![Windows Cold DR with PD Async Replication](./images/Windows%20Cold%20DR%20Architecture.png)

## Setup Folder
Contains code to spin up 10 Windows Server servers and join them to a domain, create secondary disks for all 10 and the domain controller (if using) in the DR region, and create the asynchronous replication pairs for all secondary disks.  The code is written to preserve IP addresses for DR.  

## DR Folder
Contains code to spin up DR servers using the replicated secondary disks (including the domain controller), create failback secondary disks, and create the failback async replication pairs.  The IP addresses are preserved for failback to production.

## Failback Folder
Contains code to spin up failback/production servers using the replicated secondary disks, create failback secondary disks, and create the failback async replication pairs.

# How to Setup the Environment
1. Navigate to the Setup folder
2. Populate the .tfvars file with your values
3. Navigate to the templatefiles folder and update `ad-join.tpl` with your values (or use your own domain join script)
4. Navigate back to the Setup directory, and run `terraform apply` to deploy 10 Windows Server servers and join them to your domain
    - Allow 15-20 minutes for initial replication to complete
    - If using your own systems with larger disks, initial replication time may be longer. The initial replication is complete when the disk/async_replication/time_since_last_replication metric is available in Cloud Monitoring.
5. Populate DR and Failback folder .tfvars files with repsective values

***If not using a domain controller, you will need to comment out lines 26-32 in prod-async-rep.tf and lines 54 to 87 in prod-sec-boot-disks.tf.***

# Failover
1. Simulate DR event (shut down the VMs)
2. Navigate to the setup folder and rename `prod-async-rep.tf` to `prod-async-rep.tf.dr`
3. Run terraform apply to terminate replication
4. Sever VPC peering from shared-svcs to prod, and establish VPC peering from shared-svcs to DR
5. Navigate to the dr folder
6. Run `terraform apply` to recover the VMs in the DR region
7. Validate all servers and applications are back online
8. Delete the old production VMs and their disks

***If not using a domain controller, you will need to comment out lines 26-32 in dr-east-async-rep.tf and lines 18, 54 to 88 in dr-east-sec-boot-disks.tf.***

# Failback
1. Navigate to the dr folder
2. Rename `dr-east-async-rep.tf.dr` to `dr-east-async-rep.tf`
3. Rename `dr-east-sec-boot-disks.tf.dr` to `dr-east-sec-boot-disks.tf`
4. Run `terraform apply` to create secondary disks in production region and establish async replication
    - Allow 15-20 minutes for initial replication to complete
    - If using your own systems with larger disks, initial replication time may be longer. The initial replication is complete when the disk/async_replication/time_since_last_replication metric is available in Cloud Monitoring.
5. Shut down DR VMs
6. Rename `dr-east-async-rep.tf` to `dr-east-async-rep.tf.failback`
7. Run `terraform apply` to terminate replication
8. Navigate to the failback folder
9. Run `terraform apply` to recover your VMs in the original production region
10. Validate all servers and applications are back online

***If not using a domain controller, you will need to comment out lines 26-32 in dr-east-async-rep.tf and lines 18, 54 to 88 in dr-east-sec-boot-disks.tf.***