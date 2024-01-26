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

####################
### DR Variables ###
####################

variable "use-domain-controller" {
  type = bool
  description = "Set value to TRUE if you plan to manually build a Domain Controller as part of the demo. The default value will be set to FALSE"
}

variable "app-dr-project" {
  type        = string
  description = "The DR project"
}

variable "app-dc-gce-display-name" {
  type        = string
  description = "The domain controller name in the GCE console"
}

variable "app-dc-disk-type" {
  type        = string
  description = "The DR domain controller boot disk type"
}

variable "app-dc-machine-type" {
  type        = string
  description = "The DR domain controller machine type"
}

variable "app-dr-subnet" {
  type        = string
  description = "The DR subnet"
}

variable "app-dr-dc-ip" {
  type        = string
  description = "The DR domain controller IP"
}

variable "app-dr-service-account" {
  type        = string
  description = "The DR GCE service account"
}

variable "app-dr-dc-zone" {
  type        = string
  description = "The DR zone to contain the domain controller"
}

#####################################
### Failback/Production Variables ###
#####################################
variable "app-prod-project" {
  type        = string
  description = "The failback/production project"
}

variable "app-prod-dc-zone" {
  type        = string
  description = "The failback/production zone to contain the domain controller"
}