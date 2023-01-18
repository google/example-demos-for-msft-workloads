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

### OUTPUTS ### 

output "project_name" {
  description = "Generated value of the Project"
  value       = var.provider_project
}

output "jumpbox_info" {
  description = "Connectivity Info for Jumpbox"
  value       = <<JUMPBOX
    Using your RDP client, connect to this IP: ${google_compute_instance.jumpbox.network_interface[0].access_config[0].nat_ip}.
    Username: Administrator
    Password: Navigate to Cloud Console > Security > Secrets Manager > ${google_secret_manager_secret.local_admin.secret_id}

    Once logged in, you will be able to access the On-Prem Domain Controller and the Management VM for Managed AD.
    There are RDP connections already configured on the Desktop for when you login, along with the instructions to
    retrieve the passwords. 

    The Management VM has SQL Server Management Studio already installed so you can connect to Cloud SQL Server. 
    JUMPBOX
}