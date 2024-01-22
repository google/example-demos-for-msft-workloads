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

### OUTPUT ### 

output "instructions_to_access_environment" {
  description = "Instructions to access environment"
  value       = "\n\tLogin to the Jumpbox Server using IAP.\n\n\tCredentials\n\t\tRun this command> gcloud secrets versions access latest --secret=${google_secret_manager_secret.ad_admin.secret_id} --project=${var.provider_project}\n\n\tIAP Tunnel\n\t\tRun this command> gcloud compute start-iap-tunnel ${google_compute_instance.jumpbox.name} 3389 --local-host-port=localhost:50001 --zone=${var.prod_zone} --project=${var.provider_project}\n\n\t\tAfter the Tunnel is established, use any RDP Client to connect to localhost:50001 and use the Credentials to authenticate to the Jumpbox."
}