

variable "app-prod-east-ip-subnet" {
  type        = string
  description = "The subnet in East4 to associate the production app server IP address resources with"
}

variable "app-prod-east-ip-region" {
  type        = string
  description = "The region to store the production app server IP address resources"
}

variable "app-dr-east-project" {
  type        = string
  description = "The DR project to contain the secondary boot disks"
}

variable "app-prod-east-project" {
  type        = string
  description = "The project containing the app server primary boot disks"
}

variable "app-dr-region" {
  type        = string
  description = "The DR project to create the secondary boot disks in"
}

variable "app-failback-dc-zone" {
  type        = string
  description = "The zone to contain the domain controller secondary boot disk"
}

variable "app-failback-region" {
  type        = string
  description = "The DR project to create the secondary boot disks in"
}

variable "dr-dc-zone" {
  type        = string
  description = "The zone to contain the domain controller secondary boot disk"
}

variable "dr-east-dc-gce-display-name" {
  type        = string
  description = "The DR east domain controller name in the GCE console"
}

variable "failback-east-dc-gce-display-name" {
  type        = string
  description = "The DR east domain controller name in the GCE console"
}

variable "dr-east-dc-pri-boot-disk-selflink" {
  type        = string
  description = "The east domain controller dr boot disk self link"
}

variable "app-east-dc-disk-type" {
  type        = string
  description = "The DR domain controller secondary boot disk type"
}

variable "east-dc-machine-type" {
  type        = string
  description = "The DR domain controller machine type"
}

variable "east-dr-subnet" {
  type        = string
  description = "The DR subnet"
}

variable "east-dr-dc-ip" {
  type        = string
  description = "The DR domain controller machine type"
}

variable "east-dr-sa" {
  type        = string
  description = "The DR east GCE service account"
}

variable "east-dr-sa-scopes" {
  type        = list
  description = "The DR east GCE service account"
}