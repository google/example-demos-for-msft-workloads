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

variable "app-prod-service-account-scopes" {
  type        = string
  description = "The scopes for the production GCE service account"
}

variable "app-prod-ip-subnet" {
  type        = string
  description = "The subnet to associate the production app servers with"
}

variable "app-prod-dc-gce-display-name" {
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