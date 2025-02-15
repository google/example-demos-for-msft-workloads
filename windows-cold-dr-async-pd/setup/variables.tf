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

######################
### Prod Variables ###
######################

variable "use-domain-controller" {
  type = bool
  description = "Set value to TRUE if you plan to manually build a Domain Controller as part of the demo. The default value will be set to FALSE"
}

variable "use-sql" {
  type = bool
  description = "Set value to TRUE if you plan to manually build a SQL Server as part of the demo. The default value will be set to FALSE"
}

variable "app-prod-project" {
  type        = string
  description = "The production project"
}

variable "app-prod-region" {
  type        = string
  description = "The production region"
}

variable "app-prod-tpl-self-link" {
  type        = string
  description = "The self link to the app server template"
}

variable "app-prod-service-account" {
  type        = string
  description = "The email address of the production GCE service account"
}

variable "app-prod-ip-subnet-self-link" {
  type        = string
  description = "The subnet to associate the production app servers with"
}

variable "app-dc-gce-display-name" {
  type        = string
  description = "The production domain controller name in the GCE console"
}

variable "app-prod-dc-disk-selflink" {
  type        = string
  description = "The production domain controller boot disk self link"
}

variable "app-dc-disk-type" {
  type        = string
  description = "The production domain controller boot disk type"
}

variable "app-prod-dc-zone" {
  type        = string
  description = "The production zone to contain the domain controller"
}

variable "app-sql-gce-display-name" {
  type = string
  description = "The GCE display name of the SQL Server instance"
}

variable "app-prod-sql-disk-selflink" {
  type = string
  description = "The selflink of the production SQL Server boot disk"
}

variable "app-sql-disk-type" {
  type = string
  description = "The persistent disk type of the SQL Server disks"
}

variable "app-prod-sql-zone" {
  type = string
  description = "The production zone for the SQL Server"
}

variable "app-sql-data-disk-name" {
  type = string
  description = "The failback/production SQL Server data disk name"
}

####################
### DR Variables ###
####################
variable "app-dr-project" {
  type        = string
  description = "The DR project"
}

variable "app-dr-region" {
  type        = string
  description = "The DR region"
}

variable "app-dr-dc-zone" {
  type        = string
  description = "The DR zone to contain the domain controller boot disk"
}

variable "app-dr-sql-zone" {
  type = string
  description = "The DR zone to contain the SQL Server"
}