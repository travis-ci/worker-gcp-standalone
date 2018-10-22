variable "worker_docker_self_image" {
  default = "travisci/worker:v4.5.1-21-g60ec16c"
}

variable "worker_managed_instance_count" {
  default = "1"
}

resource "google_service_account" "worker" {
  account_id   = "worker"
  display_name = "travis-worker processes"
  project      = "${var.project}"
}

resource "google_project_iam_custom_role" "worker" {
  role_id     = "worker"
  title       = "travis-worker"
  description = "A travis-worker process that can do travis-worky stuff"

  permissions = [
    "cloudtrace.traces.patch",
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
    "compute.images.list",
    "compute.images.useReadOnly",
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

resource "google_project_iam_member" "worker" {
  project = "${var.project}"
  role    = "projects/${var.project}/roles/${google_project_iam_custom_role.worker.role_id}"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

data "template_file" "worker_cloud_config" {
  template = "${file("${path.module}/assets/cloud-config-worker.yml.tpl")}"

  vars {
    docker_image = "${var.worker_docker_self_image}"

    config = <<EOF
${file("${path.module}/worker.env")}
TRAVIS_WORKER_GCE_REGION=${var.region}
TRAVIS_WORKER_QUEUE_NAME=${var.queue_name}
TRAVIS_WORKER_AMQP_URI=${var.amqp_uri}
TRAVIS_WORKER_BUILD_API_URI=${var.build_api_uri}
EOF

    honeycomb_dataset     = "${var.honeycomb_dataset}"
    honeycomb_writekey    = "${var.honeycomb_writekey}"
    honeycomb_sample_rate = "${var.honeycomb_sample_rate}"
  }
}

resource "google_compute_instance_template" "worker" {
  name_prefix = "worker-"

  machine_type = "${var.machine_type}"
  tags         = ["worker"]
  project      = "${var.project}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    auto_delete  = true
    boot         = true
    source_image = "${var.cos_image}"
  }

  network_interface {
    network = "default"

    access_config {
      # ephemeral ip
    }
  }

  metadata {
    "user-data" = "${data.template_file.worker_cloud_config.rendered}"
  }

  lifecycle {
    create_before_destroy = true
  }

  service_account {
    email  = "${google_service_account.worker.email}"
    scopes = [
      "cloud-platform",
      "storage-full",
      "compute-rw",
      "trace-append"
    ]
  }
}

resource "google_compute_region_instance_group_manager" "worker" {
  provider = "google-beta"

  base_instance_name = "worker"
  name               = "worker"
  target_size        = "${var.worker_managed_instance_count}"
  region             = "${var.region}"

  distribution_policy_zones = "${formatlist("${var.region}-%s", var.zones)}"

  version {
    name              = "default"
    instance_template = "${google_compute_instance_template.worker.self_link}"
  }
}

output "worker_service_account_email" {
  value = "${google_service_account.worker.email}"
}
