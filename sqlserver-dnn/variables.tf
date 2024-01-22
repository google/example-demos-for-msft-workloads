/**
 * Copyright 2024 Google LLC
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

### VARIABLES ###

variable "provider_project" {
  description = "The Project ID that will be used for the demo"
}

variable "prod_region" {
  description = "The Prod Compute region for the demo"
  default     = "us-central1"
}

variable "prod_zone" {
  description = "The Prod Compute zone for the demo"
  default     = "us-central1-f"
}

variable "prod_network_name" {
  description = "The name for the Prod Network VPC"
  default     = "prod-vpc"
}

variable "prod_subnets" {
  description = "The list of subnets to be created in the Prod VPC"
  default = [
    {
      subnet_name           = "prod-subnet-us-central1"
      subnet_ip             = "10.145.0.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = "true"
    }
  ]
}

variable "dc1_hostname" {
  description = "Hostname for the Primary Domain Controller"
  default     = "dc1"
}

variable "sql1_hostname" {
  description = "Hostname for the Primary SQL Server AlwaysOn Node"
  default     = "sql1"
}

variable "sql2_hostname" {
  description = "Hostname for the Secondary SQL Server AlwaysOn Node"
  default     = "sql2"
}

variable "web1_hostname" {
  description = "Hostname for the Web Server"
  default     = "web1"
}

variable "witness_hostname" {
  description = "Hostname for the Cluster Witness Server"
  default     = "witness"
}

variable "jumpbox_hostname" {
  description = "Hostname for the Jumpbox Server"
  default     = "jumpbox"
}

variable "ad_domain_name" {
  description = "Active Directory Domain Name configured on DC1"
  default     = "example.com"
}

variable "sql_service_account_name" {
  description = "SQL Service Account Username"
  default     = "sql-svc"
}

variable "web_service_account_name" {
  description = "Web Server user for connection string"
  default     = "web-user"
}

variable "aoag_name" {
  description = "AlwaysOn Availability Group Name"
  default     = "aoag-dnn"
}

variable "dnn_listener_name" {
  description = "AlwaysOn Availability Group Distributed Network Name (DNN) Listerner Name"
  default     = "dnn-listener"
}

variable "dnn_listener_port" {
  description = "Distributed Network Name (DNN) Listerner TCP Port - DO NOT USE TCP 1433"
  default     = "6789"
}

variable "database_backup_url" {
  description = "The direct download URL for the Sample Database"
  default     = "https://github.com/google/msft-on-gcp-code-samples/tree/sql-server-dnn/sqlserver-dnn/files/ContosoUniversity.bak"

}

variable "website_url" {
  description = "The direct download URL for the Sample Web App"
  default     = "https://github.com/google/msft-on-gcp-code-samples/tree/sql-server-dnn/sqlserver-dnn/files/samplewebapp.zip"
}