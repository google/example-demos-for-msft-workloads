/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

### VARIABLES CONFIG ### 

variable "provider_project" {
  description = "The Google Project defined in the Google provider configuration"
}

variable "default_region" {
  description = "The default Google Region for resources"
  default     = "us-central1"
}

variable "default_zone" {
  description = "The default Google Region Zone for resources"
  default     = "us-central1-a"
}

variable "demos_folder_name" {
  description = "The name of the Folder created under the Organization to house the demo"
  default     = "demos"
}

variable "modifier" {
  description = "A user provided value to help with Project uniqueness"
  default     = "demo"
}

variable "vpc_network_name" {
  description = "The name of the custom mode VPC in the Project"
  default     = "tf-demo-vpc"
}

variable "vpc_subnets" {
  description = "The list of subnets to be created in the VPC"
  default = [
    {
      subnet_name           = "demo-vpc-subnet-us-central1"
      subnet_ip             = "10.145.0.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = "true"
    }
  ]
}

variable "allowed_ips_for_rdp_to_jumpbox" {
  description = "The list of IPs allowed direct RDP access to the Jumpbox"
  default     = ["0.0.0.0/0"]
}

variable "cloud_sql_service_networking_cidr" {
  description = "The /24 CIDR block used for Cloud SQL Server Service Networking. DO NOT SPECIFY MASK"
  default     = "10.20.10.0"
}

variable "jumpbox_hostname" {
  description = "OS Hostname for Jumpbox Server"
  default     = "jumpbox"
}

variable "dc1_hostname" {
  description = "OS Hostname for DC1"
  default     = "dc1"
}

variable "mgmt_vm_hostname" {
  description = "OS Hostname for mgmt-vm"
  default     = "mgmt-vm"
}

variable "on_prem_ad_domain_name" {
  description = "Active Directory Domain Name configured on DC1"
  default     = "example.com"
}

variable "managed_ad_domain_name" {
  description = "Managed Service for Microsoft Active Directory Domain Name"
  default     = "gcpexample.com"
}

variable "managed_ad_cidr" {
  description = "The /24 CIDR block used by Managed AD"
  default     = "10.10.10.0/24"
}

variable "cloudsql_instance_name" {
  description = "Instance name for Cloud SQL Server Instance"
  default     = "test-cloudsql"
}