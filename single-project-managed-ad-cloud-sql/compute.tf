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

### COMPUTE ENGINE INSTANCES CONFIG ### 

resource "google_compute_instance" "dc1" {
  name         = var.dc1_hostname
  machine_type = "e2-standard-2"
  zone         = var.default_zone

  depends_on = [
    google_secret_manager_secret_version.local_admin,
    google_secret_manager_secret_version.adds_dsrm,
    google_secret_manager_secret_version.adds_trust_password,
    google_dns_policy.inbound_policy
  ]

  tags = ["rdp", "dc"]

  boot_disk {
    initialize_params {
      image = "windows-2022"
      size  = 50
      type  = "pd-balanced"
    }
    device_name = var.dc1_hostname
  }

  network_interface {
    network    = module.network.network_id
    subnetwork = module.network.subnets_ids[0]
  }

  metadata = {
    domain = var.on_prem_ad_domain_name
    sysprep-specialize-script-ps1 = templatefile("./templatefiles/on-prem-dc.tpl", {
      project_name                  = var.provider_project
      dc1_os_hostname               = var.dc1_hostname
      dc1_zone                      = var.default_zone
      on_prem_ad_domain_name        = var.on_prem_ad_domain_name
      on_prem_ad_domain_netbios     = local.on_prem_ad_netbios
      managed_ad_domain_name        = var.managed_ad_domain_name
      managed_ad_domain_netbios     = local.managed_ad_netbios
      local_admin_secret_id         = google_secret_manager_secret.local_admin.secret_id
      adds_dsrm_secret_id           = google_secret_manager_secret.adds_dsrm.secret_id
      user_password_secret_id       = google_secret_manager_secret.on_prem_ad_user_password.secret_id
      on_prem_ad_admin_secret_id    = google_secret_manager_secret.on_prem_ad_admin.secret_id
      managed_ad_admin_secret_id    = google_secret_manager_secret.managed_ad_admin.secret_id
      adds_trust_password_secret_id = google_secret_manager_secret.adds_trust_password.secret_id
    })
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.demo_compute.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "mgmt_vm" {
  name         = var.mgmt_vm_hostname
  machine_type = "e2-standard-2"
  zone         = var.default_zone

  depends_on = [
    google_secret_manager_secret_version.local_admin
  ]

  tags = ["rdp", "mgmt-vm"]

  boot_disk {
    initialize_params {
      image = "windows-2022"
      size  = 50
      type  = "pd-balanced"
    }
    device_name = var.mgmt_vm_hostname
  }

  network_interface {
    network    = module.network.network_id
    subnetwork = module.network.subnets_ids[0]
  }

  metadata = {
    domain = var.managed_ad_domain_name
    sysprep-specialize-script-ps1 = templatefile("./templatefiles/mgmt-vm-script.tpl", {
      project_name               = var.provider_project
      mgmt_vm_os_hostname        = var.mgmt_vm_hostname
      mgmt_vm_zone               = var.default_zone
      managed_ad_domain_name     = var.managed_ad_domain_name
      local_admin_secret_id      = google_secret_manager_secret.local_admin.secret_id
      managed_ad_admin_secret_id = google_secret_manager_secret.managed_ad_admin.secret_id
    })
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.demo_compute.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "jumpbox" {
  name         = var.jumpbox_hostname
  machine_type = "e2-standard-2"
  zone         = var.default_zone

  tags = ["rdp", "jumpbox"]

  boot_disk {
    initialize_params {
      image = "windows-2022"
      size  = 50
      type  = "pd-balanced"
    }
    device_name = var.jumpbox_hostname
  }

  network_interface {
    network    = module.network.network_id
    subnetwork = module.network.subnets_ids[0]
    access_config {

    }
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile("./templatefiles/jumpbox.tpl", {
      jumpbox_os_hostname        = var.jumpbox_hostname
      jumpbox_vm_zone            = var.default_zone
      dc1_ip_address             = google_compute_instance.dc1.network_interface[0].network_ip
      mgmt_vm_ip_address         = google_compute_instance.mgmt_vm.network_interface[0].network_ip
      on_prem_ad_domain_netbios  = local.on_prem_ad_netbios
      managed_ad_domain_netbios  = local.managed_ad_netbios
      on_prem_ad_admin_secret_id = google_secret_manager_secret.on_prem_ad_admin.secret_id
      managed_ad_admin_secret_id = google_secret_manager_secret.managed_ad_admin.secret_id
      local_admin_secret_id      = google_secret_manager_secret.local_admin.secret_id
    })
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.demo_compute.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}
