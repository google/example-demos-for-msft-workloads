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

### FIREWALL CONFIG ### 

module "prod_firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  version      = "6.0.0"
  project_id   = var.provider_project
  network_name = module.prod_vpc.network_name

  rules = [{
    name                    = "allow-iap-tcp-forwarding-prod-vpc"
    description             = "Allow Google Cloud IAP TCP Forwarding"
    direction               = "INGRESS"
    priority                = 1000
    ranges                  = ["35.235.240.0/20"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    allow = [{
      protocol = "tcp"
      ports    = ["22", "3389"]
    }]
    deny = []
    log_config = {
      metadata = "INCLUDE_ALL_METADATA"
    }
    },
    {
      name                    = "allow-google-dns-proxy-prod-vpc"
      description             = "Allow Google DNS to forward DNS queries to Domain Controller"
      direction               = "INGRESS"
      priority                = 1000
      ranges                  = ["35.199.192.0/19"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = ["dc"]
      target_service_accounts = null
      allow = [
        {
          protocol = "tcp"
          ports    = ["53"]
        },
        {
          protocol = "udp"
          ports    = ["53"]
        }
      ]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name                    = "allow-internal-prod-vpc"
      description             = "Allow all internal communication"
      direction               = "INGRESS"
      priority                = 1000
      ranges                  = ["${module.prod_vpc.subnets_ips[0]}"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = null
      target_service_accounts = null
      allow = [
        {
          protocol = "all"
          ports    = []
        }
      ]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    }
  ]
}