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
app-prod-project = "REPLACE_WITH_SERVICE_PROJECT_FOR_PRODUCTION_PROJECT_ID"

app-prod-region = "REPLACE_WITH_PRODUCTION_REGION"
# Default is us-east4 

app-prod-tpl-self-link = "REPLACE_WITH_SELF_LINK_FOR_INSTANCE_TEMPLATE"
# Run this gcloud command to get the link
# > gcloud compute instance-templates describe app-server-tpl --project=REPLACE_WITH_SERVICE_PROJECT_FOR_PRODUCTION_PROJECT_ID --format="value(selfLink)"

app-prod-service-account = "REPLACE_WITH_COMPUTE_ENGINE_DEFAULT_SERVICE_ACCOUNT"
# Run this gcloud command to get the Service Account
# > gcloud iam service-accounts list --project=REPLACE_WITH_SERVICE_PROJECT_FOR_PRODUCTION_PROJECT_ID

app-prod-service-account-scopes = "REPLACE_WITH_SCOPE"
# Default scope is Cloud Platform = https://www.googleapis.com/auth/cloud-platform 

app-prod-ip-subnet = "REPLACE_WITH_IP_SUBNET_FOR_PROD"
# Default is 10.1.0.0/21

app-dc-gce-display-name = "REPLACE_WITH_DOMAIN_CONTROLLER_GCE_NAME"
# Comment out the variable if you are not using a Domain Controller

app-prod-dc-disk-selflink = "REPLACE_WITH_DOMAIN_CONTROLLER_DISK_SELFLINK"
# Comment out the variable if you are not using a Domain Controller

app-dc-disk-type = "REPLACE_WITH_DISK_TYPE"
# Comment out the variable if you are not using a Domain Controller

app-prod-dc-zone = "REPLACE_WITH_ZONE"
# Comment out the variable if you are not using a Domain Controller

####################
### DR Variables ###
####################
app-dr-project = "REPLACE_WITH_SERVICE_PROJECT_FOR_DR_PROJECT_ID"

app-dr-region = "REPLACE_WITH_DR_REGION"
# Default is us-central1

app-dr-dc-zone = "REPLACE_WITH_ZONE"
# Comment out the variable if you are not using a Domain Controller