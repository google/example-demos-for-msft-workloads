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

### COMPUTE CONFIG ### 

resource "google_compute_instance" "dc1" {

  project      = var.provider_project
  name         = var.dc1_hostname
  machine_type = "n2-standard-8"
  zone         = var.prod_zone

  depends_on = [
    google_secret_manager_secret_version.local_admin,
    google_secret_manager_secret_version.adds_dsrm
  ]

  tags = ["rdp", "dc"]

  boot_disk {
    initialize_params {
      image = "family/windows-2022"
      size  = 50
      type  = "pd-balanced"
    }
    device_name = var.dc1_hostname
  }

  network_interface {
    network    = module.prod_vpc.network_id
    subnetwork = module.prod_vpc.subnets_ids[0]
  }

  metadata = {
    domain = var.ad_domain_name
    sysprep-specialize-script-ps1 = templatefile("./templatefiles/dc1.tpl", {
      project_name                  = var.provider_project
      dc1_os_hostname               = var.dc1_hostname
      dc1_zone                      = var.prod_zone
      ad_domain_name                = var.ad_domain_name
      ad_domain_netbios             = local.ad_domain_netbios
      prod_subnets                  = var.prod_subnets[0].subnet_ip
      sql_service_account_name      = var.sql_service_account_name
      web_service_account_name      = var.web_service_account_name
      local_admin_secret_id         = google_secret_manager_secret.local_admin.secret_id
      adds_dsrm_secret_id           = google_secret_manager_secret.adds_dsrm.secret_id
      user_password_secret_id       = google_secret_manager_secret.ad_user_password.secret_id
      ad_admin_secret_id            = google_secret_manager_secret.ad_admin.secret_id
      sql_service_account_secret_id = google_secret_manager_secret.sql_service.secret_id
      web_service_account_secret_id = google_secret_manager_secret.web_service.secret_id
    })
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.prod_compute_service_account.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "sql1" {

  project      = var.provider_project
  name         = var.sql1_hostname
  machine_type = "n2-standard-4"
  zone         = var.prod_zone

  depends_on = [
    google_compute_instance.dc1
  ]

  tags = ["rdp", "sql"]

  boot_disk {
    initialize_params {
      image = "windows-sql-cloud/sql-std-2022-win-2022"
      size  = 50
      type  = "pd-balanced"
    }
    device_name = var.sql1_hostname
  }

  network_interface {
    network    = module.prod_vpc.network_id
    subnetwork = module.prod_vpc.subnets_ids[0]
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile("./templatefiles/sql1.tpl", {
      project_name                  = var.provider_project
      dc1_os_hostname               = var.dc1_hostname
      dc1_zone                      = var.prod_zone
      sql1_os_hostname              = var.sql1_hostname
      sql1_zone                     = var.prod_zone
      sql2_os_hostname              = var.sql2_hostname
      witness_os_hostname           = var.witness_hostname
      sql_service_account           = var.sql_service_account_name
      web_service_account           = var.web_service_account_name
      aoag_name                     = var.aoag_name
      dnn_listener_name             = var.dnn_listener_name
      dnn_listener_port             = var.dnn_listener_port
      wsfc_cluster_ip               = google_compute_address.wsfc_cluster_ip.address
      ad_domain_netbios             = local.ad_domain_netbios
      ad_domain_name                = var.ad_domain_name
      local_admin_secret_id         = google_secret_manager_secret.local_admin.secret_id
      sql_service_account_secret_id = google_secret_manager_secret.sql_service.secret_id
      sample_database_url           = var.database_backup_url
    })
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.prod_compute_service_account.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "sql2" {

  project      = var.provider_project
  name         = var.sql2_hostname
  machine_type = "n2-standard-4"
  zone         = var.prod_zone

  depends_on = [
    google_compute_instance.dc1
  ]

  tags = ["rdp", "sql"]

  boot_disk {
    initialize_params {
      image = "windows-sql-cloud/sql-std-2022-win-2022"
      size  = 50
      type  = "pd-balanced"
    }
    device_name = var.sql2_hostname
  }

  network_interface {
    network    = module.prod_vpc.network_id
    subnetwork = module.prod_vpc.subnets_ids[0]
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile("./templatefiles/sql2.tpl", {
      project_name                  = var.provider_project
      dc1_os_hostname               = var.dc1_hostname
      dc1_zone                      = var.prod_zone
      sql2_os_hostname              = var.sql2_hostname
      sql2_zone                     = var.prod_zone
      sql_service_account           = var.sql_service_account_name
      dnn_listener_port             = var.dnn_listener_port
      ad_domain_netbios             = local.ad_domain_netbios
      ad_domain_name                = var.ad_domain_name
      local_admin_secret_id         = google_secret_manager_secret.local_admin.secret_id
      sql_service_account_secret_id = google_secret_manager_secret.sql_service.secret_id
    })
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.prod_compute_service_account.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "web1" {

  project      = var.provider_project
  name         = var.web1_hostname
  machine_type = "n2-standard-4"
  zone         = var.prod_zone

  depends_on = [
    google_compute_instance.dc1
  ]

  tags = ["rdp", "web"]

  boot_disk {
    initialize_params {
      image = "family/windows-2022"
      size  = 50
      type  = "pd-balanced"
    }
    device_name = var.web1_hostname
  }

  network_interface {
    network    = module.prod_vpc.network_id
    subnetwork = module.prod_vpc.subnets_ids[0]
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile("./templatefiles/web1.tpl", {
      project_name          = var.provider_project
      dc1_os_hostname       = var.dc1_hostname
      dc1_zone              = var.prod_zone
      web1_os_hostname      = var.web1_hostname
      web1_zone             = var.prod_zone
      web_service_account   = var.web_service_account_name
      dnn_listener_name     = var.dnn_listener_name
      dnn_listener_port     = var.dnn_listener_port
      ad_domain_netbios     = local.ad_domain_netbios
      ad_domain_name        = var.ad_domain_name
      local_admin_secret_id = google_secret_manager_secret.local_admin.secret_id
      web_service_secret_id = google_secret_manager_secret.web_service.secret_id
      sample_website_url    = var.website_url
    })
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.prod_compute_service_account.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "witness" {

  project      = var.provider_project
  name         = var.witness_hostname
  machine_type = "e2-medium"
  zone         = var.prod_zone

  depends_on = [
    google_compute_instance.sql2
  ]

  tags = ["rdp", "file", "witness"]

  boot_disk {
    initialize_params {
      image = "family/windows-2022"
      size  = 50
      type  = "pd-balanced"
    }
    device_name = var.witness_hostname
  }

  network_interface {
    network    = module.prod_vpc.network_id
    subnetwork = module.prod_vpc.subnets_ids[0]
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile("./templatefiles/witness.tpl", {
      project_name          = var.provider_project
      dc1_os_hostname       = var.dc1_hostname
      dc1_zone              = var.prod_zone
      witness_os_hostname   = var.witness_hostname
      witness_zone          = var.prod_zone
      ad_domain_netbios     = local.ad_domain_netbios
      ad_domain_name        = var.ad_domain_name
      local_admin_secret_id = google_secret_manager_secret.local_admin.secret_id
    })
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.prod_compute_service_account.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_compute_instance" "jumpbox" {

  project      = var.provider_project
  name         = var.jumpbox_hostname
  machine_type = "e2-standard-2"
  zone         = var.prod_zone

  depends_on = [
    google_compute_instance.witness
  ]

  tags = ["rdp", "jumpbox"]

  boot_disk {
    initialize_params {
      image = "family/windows-2022"
      size  = 50
      type  = "pd-balanced"
    }
    device_name = var.jumpbox_hostname
  }

  network_interface {
    network    = module.prod_vpc.network_id
    subnetwork = module.prod_vpc.subnets_ids[0]
  }

  metadata = {
    sysprep-specialize-script-ps1 = templatefile("./templatefiles/jumpbox.tpl", {
      project_name          = var.provider_project
      dc1_os_hostname       = var.dc1_hostname
      dc1_zone              = var.prod_zone
      jumpbox_os_hostname   = var.jumpbox_hostname
      jumpbox_zone          = var.prod_zone
      ad_domain_netbios     = local.ad_domain_netbios
      ad_domain_name        = var.ad_domain_name
      local_admin_secret_id = google_secret_manager_secret.local_admin.secret_id
      ad_admin_secret_id    = google_secret_manager_secret.ad_admin.secret_id
    })
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.prod_compute_service_account.email
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}