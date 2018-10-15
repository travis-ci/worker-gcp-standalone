variable "managed_instance_count" {}

variable "machine_type" {
  default = "n1-standard-1"
}

variable "project" {}
variable "region" {}
variable "worker_docker_self_image" {}
variable "worker_image" {}

variable "zones" {
  default = ["a", "b", "c", "f"]
}

resource "google_service_account" "workers" {
  account_id   = "workers"
  display_name = "travis-worker processes"
  project      = "${var.project}"
}

resource "google_project_iam_custom_role" "worker" {
  role_id     = "worker"
  title       = "travis-worker"
  description = "A travis-worker process that can do travis-worky stuff"

  permissions = [
    "compute.acceleratorTypes.get",
    "compute.acceleratorTypes.list",
    "compute.addresses.create",
    "compute.addresses.createInternal",
    "compute.addresses.delete",
    "compute.addresses.deleteInternal",
    "compute.addresses.get",
    "compute.addresses.list",
    "compute.addresses.setLabels",
    "compute.addresses.use",
    "compute.addresses.useInternal",
    "compute.diskTypes.get",
    "compute.diskTypes.list",
    "compute.disks.create",
    "compute.disks.createSnapshot",
    "compute.disks.delete",
    "compute.disks.get",
    "compute.disks.getIamPolicy",
    "compute.disks.list",
    "compute.disks.resize",
    "compute.disks.setIamPolicy",
    "compute.disks.setLabels",
    "compute.disks.update",
    "compute.disks.use",
    "compute.disks.useReadOnly",
    "compute.globalOperations.get",
    "compute.globalOperations.list",
    "compute.instances.addAccessConfig",
    "compute.instances.addMaintenancePolicies",
    "compute.instances.attachDisk",
    "compute.instances.create",
    "compute.instances.delete",
    "compute.instances.deleteAccessConfig",
    "compute.instances.detachDisk",
    "compute.instances.get",
    "compute.instances.getGuestAttributes",
    "compute.instances.getIamPolicy",
    "compute.instances.getSerialPortOutput",
    "compute.instances.list",
    "compute.instances.listReferrers",
    "compute.instances.osAdminLogin",
    "compute.instances.osLogin",
    "compute.instances.removeMaintenancePolicies",
    "compute.instances.reset",
    "compute.instances.setDeletionProtection",
    "compute.instances.setDiskAutoDelete",
    "compute.instances.setIamPolicy",
    "compute.instances.setLabels",
    "compute.instances.setMachineResources",
    "compute.instances.setMachineType",
    "compute.instances.setMetadata",
    "compute.instances.setMinCpuPlatform",
    "compute.instances.setScheduling",
    "compute.instances.setServiceAccount",
    "compute.instances.setShieldedVmIntegrityPolicy",
    "compute.instances.setTags",
    "compute.instances.start",
    "compute.instances.startWithEncryptionKey",
    "compute.instances.stop",
    "compute.instances.update",
    "compute.instances.updateAccessConfig",
    "compute.instances.updateNetworkInterface",
    "compute.instances.updateShieldedVmConfig",
    "compute.instances.use",
    "compute.instanceGroups.get",
    "compute.instanceGroups.list",
    "compute.machineTypes.get",
    "compute.machineTypes.list",
    "compute.networks.get",
    "compute.networks.list",
    "compute.networks.use",
    "compute.projects.get",
    "compute.regions.get",
    "compute.regions.list",
    "compute.subnetworks.get",
    "compute.subnetworks.list",
    "compute.subnetworks.use",
    "compute.subnetworks.useExternalIp",
    "compute.zoneOperations.get",
    "compute.zoneOperations.list",
    "compute.zones.get",
    "compute.zones.list",
  ]
}

resource "google_project_iam_member" "workers" {
  project = "${var.project}"
  role    = "projects/${var.project}/roles/${google_project_iam_custom_role.worker.role_id}"
  member  = "serviceAccount:${google_service_account.workers.email}"
}

resource "google_service_account_key" "workers" {
  service_account_id = "${google_service_account.workers.email}"
}

data "template_file" "cloud_init_env" {
  template = <<EOF
export TRAVIS_WORKER_SELF_IMAGE="${var.worker_docker_self_image}"
EOF
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/cloud-config.yml.tpl")}"

  vars {
    assets           = "${path.module}/../../assets"
    cloud_init_env   = "${data.template_file.cloud_init_env.rendered}"
    gce_account_json = "${base64decode(google_service_account_key.workers.private_key)}"
    here             = "${path.module}"
    syslog_address   = "${var.syslog_address}"
    worker_config    = "${var.config}"

    docker_env = <<EOF
export TRAVIS_DOCKER_DISABLE_DIRECT_LVM=1
EOF

    github_users_env = <<EOF
export GITHUB_USERS='${var.github_users}'
EOF
  }
}

resource "google_compute_instance_template" "worker" {
  name_prefix = "${var.env}-${var.index}-worker-"

  machine_type = "${var.machine_type}"
  tags         = ["worker", "${var.env}", "com", "paid"]
  project      = "${var.project}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    auto_delete  = true
    boot         = true
    source_image = "${var.worker_image}"
  }

  network_interface {
    access_config {
      # ephemeral ip
    }
  }

  metadata {
    "block-project-ssh-keys" = "true"
    "user-data"              = "${data.template_file.cloud_config.rendered}"
  }

  depends_on = ["null_resource.worker_validation"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "worker" {
  base_instance_name = "${var.env}-${var.index}-worker"
  instance_template  = "${google_compute_instance_template.worker.self_link}"
  name               = "worker"
  target_size        = "${var.managed_instance_count}"
  update_strategy    = "NONE"
  region             = "${var.region}"

  distribution_policy_zones = "${formatlist("${var.region}-%s", var.zones)}"
}
