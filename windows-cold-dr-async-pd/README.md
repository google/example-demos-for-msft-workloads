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
Contains code to spin up 10 Windows Server servers and join them to a domain, create DR boot disks for all 10, the domain controller (if using), the MS SQL Server (if using) in the DR region, and create the asynchronous replication pairs for all disks.  The code is written to preserve IP addresses.

## DR Folder
Contains code to spin up DR servers using the replicated disks and IP addresses from production (including the domain controller and MS SQL Server), create failback boot disks in the production region, and create the failback async replication pairs for all disks.  The IP addresses are preserved for failback.

## Failback Folder
Contains code to spin up failback/production servers using the replicated disks and IP addresses from DR, and includes code to recreate DR boot disks and async replication pairs to prepare for the next DR event.

# How to Setup the Environment
As of 01/2024, this repo does not contain the code necessary to build out an entire environment (coming soon!).  Some general steps and guidelines are provided here in order to help with this demo.

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
    - Enable Compute Engine, Cloud DNS, and Cloud IAP APIs in all three projects (you will have to switch between projects in gcloud)
      > gcloud services enable compute.googleapis.com dns.googleapis.com iap.googleapis.com
2. Create three (3) VPCs in the **Shared VPC Host Project**
    - VPC #1: Shared Services VPC as `shared-svcs` with global routing
        - Shared Services Subnet #1: `sn-shrdsvcs-us-east4` in `us-east4` with IP range `10.0.0.0/21` and Private Google Access enabled
        - Shared Services Subnet #2: `sn-shrdsvcs-us-central1` in `us-central1` with IP range `10.20.0.0/21` and Private Google Access enabled
    - VPC #2: Production VPC as `app-prod` with global routing
        - Production Subnet #1: `prod-app-us-east4` in `us-east4` with IP range `10.1.0.0/21` and Private Google Access enabled
    - VPC #3: DR VPC as `app-dr` with global routing
        - DR Subnet #1: `dr-app-us-central1` in `us-central1` with IP range `10.1.0.0/21`and Private Google Access enabled
        **_Note_** The IP range in DR is the same as Production
3. Create a [VPC Peering configuration](https://cloud.google.com/vpc/docs/using-vpc-peering#creating_a_peering_configuration) between the `shared-svcs` VPC and `app-prod` VPC
    - You will also need to create a VPC Peering from the `app-prod` VPC to the `shared-svcs` VPC
    - **_Optional_** You can pre-stage the peering from the `app-dr` VPC to the `shared-svcs` VPC to save time in a DR event, but it is not required at this time.

```bash
export shared_vpc_host_project="REPLACE_WITH_SHARED_VPC_HOST_PROJECT_PROJECT_ID"

# Create VPC Peering between shared-svcs and prod-vpc
gcloud compute networks peerings create shared-svcs-vpc-to-prod-vpc \
--project=$shared_vpc_host_project \
--network=shared-svcs \
--peer-network=app-prod

# Create VPC Peering between prod-vpc and shared-svcs
gcloud compute networks peerings create prod-vpc-to-shared-svcs-vpc \
--project=$shared_vpc_host_project \
--network=app-prod \
--peer-network=shared-svcs

# Run this command to verify that the new Peerings are showing as ACTIVE
gcloud compute networks peerings list \
--project=$shared_vpc_host_project \
--flatten="peerings[]" \
--format="table(peerings.name,peerings.state)"
```

4. [Enable the Shared VPC Host Project](https://cloud.google.com/vpc/docs/provisioning-shared-vpc#enable-shared-vpc-host)
5. [Attach the Production and DR Service Projects](https://cloud.google.com/vpc/docs/provisioning-shared-vpc#create-shared)
    - Ensure that you share `prod-app-us-east4` with the Production Project only
    - Ensure that you share `dr-app-us-central1` with the DR Project only
6. In the Shared VPC Host Project, configure Cloud DNS per [best practices](https://cloud.google.com/compute/docs/instances/windows/best-practices) to support your domain and Active Directory.  You will need a forwarding zone for your domain associated with Shared Services, and DNS Peering from Shared Services to the other VPCs to support domain resolution.
    - More info on Cloud DNS can be found [here](https://cloud.google.com/dns/docs/best-practices).
7. **_Optional_** If you wish to test with an Active Directory Domain, you can set up a [Domain Controller](https://cloud.google.com/architecture/deploy-an-active-directory-forest-on-compute-engine#deploy_the_active_directory_forest) in the Production Project using the `app-prod` VPC

8. **_Optional_** If you wish to test with a SQL Server, you can set up a [SQL Server](https://cloud.google.com/compute/docs/instances/sql-server/creating-sql-server-instances#start_sql_instance) in the Production Project using the `app-prod` VPC, with a second data disk attached.

9. **_Optional_** If using a SQL Server, you will need to create a Consistency Group for the boot and data disks, then add the disks to it:

    - `gcloud compute resource-policies create disk-consistency-group sql-cgroup --region=us-east4 --project=<REPLACE WITH PROD/FAILBACK PROJECT ID>`
    - `gcloud compute disks add-resource-policies <REPLACE WITH SQL BOOT DISK NAME> --zone=us-east4-a --resource-policies=sql-cgroup --project=<REPLACE WITH PROD/FAILBACK PROJECT ID>`
    - `gcloud compute disks add-resource-policies <REPLACE WITH SQL DATA DISK NAME> --zone=us-east4-a --resource-policies=sql-cgroup --project=<REPLACE WITH PROD/FAILBACK PROJECT ID>`

This is a critical step.  Once Async Replication has been enabled for a disk, you cannot add it to a consistency group.

# Building The Test Servers

> [!IMPORTANT]
> If you are not using a Domain Controller or a SQL Server to test, please ensure that the `use-domain-controller` and `use-sql` variables in `terraform.tfvars` are set to `false`

1. [Create an Instance template](https://cloud.google.com/compute/docs/instance-templates/create-instance-templates) in the Service Project for Production
    - A sample `gcloud` command has been provided in the **/setup/templatefiles** folder for your convenience

2. Navigate to the **/setup** folder and rename `terraform.tfvars.sample` to `terraform.tfvars`. Update the file with the appropriate variables for your environment
    - If you are using a Domain Controller, navigate to the **/setup/templatefiles** folder and update `ad-join.tpl` with your values. 

3. While in the **/setup** directory run the terraform commands
    - `terraform init` 
    - `terraform plan -out tf.out` (there should be 42 resources to add)
    - `terraform apply tf.out`  

   The default configuration will deploy 
    - Ten (10) Windows Servers (Domain joined if configured) 
    - Secondary boot disks in the DR Project
    - Async replication to DR

> [!NOTE]
> Please allow 5-10 minutes for initial replication to complete. If using your own systems with larger disks, initial replication time may be longer. The initial replication is complete when the `compute.googleapis.com/disk/async_replication/time_since_last_replication` metric is available in Cloud Monitoring for all disks.

```mql
# --- From the Service Project for Production ---
# Open Cloud Monitoring > Metrics expolorer > Click on "< > MQL" on the top right > Paste the following MQL
# If nothing loads it means that replication has not taken place yet. 
# You can enable auto-refresh by clicking the button right next to "SAVE CHART"

fetch gce_disk
| metric
    'compute.googleapis.com/disk/async_replication/time_since_last_replication'
| group_by 1m,
    [value_time_since_last_replication_mean:
       mean(value.time_since_last_replication)]
| every 1m
| group_by
    [resource.disk_id, metadata.system.name: metadata.system_labels.name],
    [value_time_since_last_replication_mean_aggregate:
       aggregate(value_time_since_last_replication_mean)]
```

4. **_Optional_** Navigate to the **/dr** folder and populate the terraform.tfvars values to prepare for a disaster scenario

# DR Failover

> [!IMPORTANT]
> If you are not using a Domain Controller or a SQL Server to test, please ensure that the `use-domain-controller` and `use-sql` variables in `terraform.tfvars` are set to `false`

1. Simulate a DR event (e.g. shut down the production VMs)

```bash
export app_prod_project="REPLACE_WITH_SERVICE_PROJECT_FOR_PRODUCTION_PROJECT_ID"
export zone=$(gcloud compute instances list --project=$app_prod_project --format="value(zone.basename())" | head -n 1)
for gce_instance in $(gcloud compute instances list --project=$app_prod_project --format="value(selfLink.basename())")
do
	gcloud compute instances stop $gce_instance --zone $zone --project=$app_prod_project
done
```

2. Navigate to the **/setup** folder and rename `prod-async-rep.tf` to `prod-async-rep.tf.dr`. 
   While in the **/setup** directory run the terraform commands to stop the asynchronous replication.
    - `terraform plan -out tf.out` (there should be 10 or 11 resources to destroy)
    - `terraform apply tf.out`  

3. Sever the Peering from the `shared-svcs` VPC to the `app-prod` VPC and establish a VPC Peering from the `shared-svcs` VPC to the `app-dr` VPC

```bash
export shared_vpc_host_project="REPLACE_WITH_SHARED_VPC_HOST_PROJECT_PROJECT_ID"

# Sever the Peering to prod-vpc
gcloud compute networks peerings delete "shared-svcs-vpc-to-prod-vpc" \
--project=$shared_vpc_host_project \
--network=shared-svcs

# Create VPC Peering between shared-svcs and dr-vpc
gcloud compute networks peerings create shared-svcs-vpc-to-dr-vpc \
--project=$shared_vpc_host_project \
--network=shared-svcs \
--peer-network=app-dr

# Create VPC Peering between dr-vpc and shared-svcs
gcloud compute networks peerings create dr-vpc-to-shared-svcs-vpc \
--project=$shared_vpc_host_project \
--network=app-dr \
--peer-network=shared-svcs

# Run this command to verify that the new Peerings are showing as ACTIVE
gcloud compute networks peerings list \
--project=$shared_vpc_host_project \
--flatten="peerings[]" \
--format="table(peerings.name,peerings.state)"
```

4. Navigate to the **/dr** folder and update the `terraform.tfvars` file with the appropriate variables for your environment if not already populated

5. While in the **/dr** folder, run the terraform commands to create the DR VMs using the replicated disks from Production
    - `terraform init` 
    - `terraform plan -out tf.out` (there should be 10 or 11 resources to create)
    - `terraform apply tf.out`  

6. Validate all servers and applications are back online and connected to the domain

7. Delete the old production VMs and their disks

```bash
export app_prod_project="REPLACE_WITH_SERVICE_PROJECT_FOR_PRODUCTION_PROJECT_ID"
export zone=$(gcloud compute instances list --project=$app_prod_project --format="value(zone.basename())" | head -n 1)
for gce_instance in $(gcloud compute instances list --project=$app_prod_project --format="value(selfLink.basename())")
do
	gcloud compute instances delete $gce_instance --zone $zone --project=$app_prod_project --quiet
done
```

8. Create a Consistency Group and add the DR disks to it:

    - `gcloud compute resource-policies create disk-consistency-group sql-cgroup --region=us-central1 --project=<REPLACE WITH DR PROJECT ID>`
    - `gcloud compute disks add-resource-policies <REPLACE WITH SQL BOOT DISK NAME> --zone=us-central1-a --resource-policies=sql-cgroup --project=<REPLACE WITH DR PROJECT ID>`
    - `gcloud compute disks add-resource-policies <REPLACE WITH SQL DATA DISK NAME> --zone=us-central1-a --resource-policies=sql-cgroup --project=<REPLACE WITH DR PROJECT ID>`

9. Rename `stage-failback-async-boot-disks.tf.dr` to `stage-failback-async-boot-disks.tf` and `stage-failback-async-rep.tf.dr` to `stage-failback-async-rep.tf`

10. While in the **/dr** folder, run the terraform commands to create new boot disks in the Production region for failback, and the associated async replication pairs from DR
    - `terraform plan -out tf.out` (should see 22 resources to add)
    - `terraform apply tf.out`  

> [!NOTE]
> Please allow 5-10 minutes for initial replication to complete. If using your own systems with larger disks, initial replication time may be longer. The initial replication is complete when the `compute.googleapis.com/disk/async_replication/time_since_last_replication` metric is available in Cloud Monitoring.

```mql
# --- From the Service Project for DR ---
# Open Cloud Monitoring > Metrics expolorer > Click on "< > MQL" on the top right > Paste the following MQL
# If nothing loads it means that replication has not taken place yet. 
# You can enable auto-refresh by clicking the button right next to "SAVE CHART"

fetch gce_disk
| metric
    'compute.googleapis.com/disk/async_replication/time_since_last_replication'
| group_by 1m,
    [value_time_since_last_replication_mean:
       mean(value.time_since_last_replication)]
| every 1m
| group_by
    [resource.disk_id, metadata.system.name: metadata.system_labels.name],
    [value_time_since_last_replication_mean_aggregate:
       aggregate(value_time_since_last_replication_mean)]
```

11. Navigate to the **/failback** folder and update the `terraform.tfvars` file with the appropriate variables for your environment to prepare for production failback

12. **_Optional_** While in the **/failback** folder, run the terraform commands to prepare for failback
    - `terraform init` 
    - `terraform plan -out tf.out` (there should be 10 or 11 resources to create)

# Production Failback

> [!IMPORTANT]
> If you are not using a Domain Controller or a SQL Server to test, please ensure that the `use-domain-controller` and `use-sql` variables in `terraform.tfvars` are set to `false`

1. Shut down DR VMs

```bash
export app_dr_project="REPLACE_WITH_SERVICE_PROJECT_FOR_DR_PROJECT_ID"
export zone=$(gcloud compute instances list --project=$app_dr_project --format="value(zone.basename())" | head -n 1)
for gce_instance in $(gcloud compute instances list --project=$app_dr_project --format="value(selfLink.basename())")
do
	gcloud compute instances stop $gce_instance --zone $zone --project=$app_dr_project
done
```

2. Navigate to the **/dr** folder

3. Rename `stage-failback-async-rep.tf` to `stage-failback-async-rep.tf.dr`

4. While in the **/dr** folder, run the terraform commands to stop replication
    - `terraform plan -out tf.out` (should see 11 resources to destroy)
    - `terraform apply tf.out`  

5. In the console, sever VPC peering from `shared-svcs` to `app-dr`, and establish VPC peering from `shared-svcs` to `app-prod`

```bash
export shared_vpc_host_project="REPLACE_WITH_SHARED_VPC_HOST_PROJECT_PROJECT_ID"

# Sever the Peering to dr-vpc
gcloud compute networks peerings delete "shared-svcs-vpc-to-dr-vpc" \
--project=$shared_vpc_host_project \
--network=shared-svcs

# Create VPC Peering between shared-svcs and prod-vpc
gcloud compute networks peerings create shared-svcs-vpc-to-prod-vpc \
--project=$shared_vpc_host_project \
--network=shared-svcs \
--peer-network=app-prod

# Run this command to verify that the new Peerings are showing as ACTIVE
gcloud compute networks peerings list \
--project=$shared_vpc_host_project \
--flatten="peerings[]" \
--format="table(peerings.name,peerings.state)"
```

6. Navigate to the **/failback** folder

7. While in the **/failback** folder, run the terraform commands to recover your VMs in the original production region using the replicated disks from DR
    - `terraform plan -out tf.out` (should see 10 or 11 resources to add)
    - `terraform apply tf.out`

8. Validate all servers and applications are back online and connected to the domain

9. Delete the old DR VMs and their disks

```bash
export app_dr_project="REPLACE_WITH_SERVICE_PROJECT_FOR_DR_PROJECT_ID"
export zone=$(gcloud compute instances list --project=$app_dr_project --format="value(zone.basename())" | head -n 1)
for gce_instance in $(gcloud compute instances list --project=$app_dr_project --format="value(selfLink.basename())")
do
	gcloud compute instances delete $gce_instance --zone $zone --project=$app_dr_project --quiet
done
```

10. Add the new production / failback disks to the Consistency Group:

    - `gcloud compute disks add-resource-policies <REPLACE WITH SQL BOOT DISK NAME> --zone=us-east4-a --resource-policies=sql-cgroup --project=<REPLACE WITH PROD/FAILBACK PROJECT ID>`
    - `gcloud compute disks add-resource-policies <REPLACE WITH SQL DATA DISK NAME> --zone=us-east4-a --resource-policies=sql-cgroup --project=<REPLACE WITH PROD/FAILBACK PROJECT ID>`

11. Rename `restage-dr-async-boot-disks.tf.failback` to `restage-dr-async-boot-disks.tf` and `restage-dr-async-rep.tf.failback` to `restage-dr-async-rep.tf`

12. While in the **/failback** folder, run the terraform commands to re-create new boot disks in the DR region, and the associated async replication pairs to prepare for the next DR event
    - `terraform plan -out tf.out` (should see 20 or 22 resources to add)
    - `terraform apply tf.out`

> [!NOTE]
> Please allow 5-10 minutes for initial replication to complete. If using your own systems with larger disks, initial replication time may be longer. The initial replication is complete when the `compute.googleapis.com/disk/async_replication/time_since_last_replication` metric is available in Cloud Monitoring.

```mql
# --- From the Service Project for Production ---
# Open Cloud Monitoring > Metrics expolorer > Click on "< > MQL" on the top right > Paste the following MQL
# If nothing loads it means that replication has not taken place yet. 
# You can enable auto-refresh by clicking the button right next to "SAVE CHART"

fetch gce_disk
| metric
    'compute.googleapis.com/disk/async_replication/time_since_last_replication'
| group_by 1m,
    [value_time_since_last_replication_mean:
       mean(value.time_since_last_replication)]
| every 1m
| group_by
    [resource.disk_id, metadata.system.name: metadata.system_labels.name],
    [value_time_since_last_replication_mean_aggregate:
       aggregate(value_time_since_last_replication_mean)]
```

# Future DR and Failback Events

In the case of future DR events, you would follow the steps in the [DR Failover](#dr-failover) section, with the following exceptions:

1. Navigate to the ~~\setup~~ **/failback** folder and rename ~~`prod-async-rep.tf` to `prod-async-rep.tf.dr`~~ `restage-dr-async-rep.tf` to `restage-dr-async-rep.tf.failback`

2. Rename ~~`stage-failback-async-boot-disks.tf.dr` to `stage-failback-async-boot-disks.tf` and~~ `stage-failback-async-rep.tf.dr` to `stage-failback-async-rep.tf`

And similary, to failback, you would follow the steps in the [Production Failback](#production-failback) section, with the following exceptions:

3. Rename ~~`restage-dr-async-boot-disks.tf.failback` to `restage-dr-async-boot-disks.tf` and~~ `restage-dr-async-rep.tf.failback` to `restage-dr-async-rep.tf`

# Cleanup

1. Navigate to the **/failback** folder
    - `terraform destroy`

2. Navigate to the **/dr** folder
    - `terraform destroy`

3. Navigate to the **/setup** folder
    - `terraform destroy`