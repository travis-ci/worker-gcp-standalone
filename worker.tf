variable "worker_docker_self_image" {
  default = "travisci/worker:v4.5.1-18-g68b538c"
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

# TODO: make worker find its own zone via metadata

data "template_file" "worker_cloud_config" {
  template = "${file("${path.module}/assets/cloud-config-worker.yml.tpl")}"

  vars {
    docker_image = "${var.worker_docker_self_image}"

    config = <<EOF
${file("${path.module}/worker.env")}
TRAVIS_WORKER_GCE_PROJECT_ID=${var.project}
TRAVIS_WORKER_STACKDRIVER_PROJECT_ID=${var.project}
TRAVIS_WORKER_GCE_REGION=${var.region}
TRAVIS_WORKER_QUEUE_NAME=${var.queue_name}
TRAVIS_WORKER_AMQP_URI=${var.amqp_uri}
TRAVIS_WORKER_BUILD_API_URI=${var.build_api_uri}
EOF
  }
}

data "template_file" "worker_container_config" {
  template = <<EOF
spec:
  containers:
  - name: travis-worker
    image: ${var.worker_docker_self_image}
    env:
    - { name: TRAVIS_WORKER_GCE_PROJECT_ID, value: '${var.project}' }
    - { name: TRAVIS_WORKER_STACKDRIVER_PROJECT_ID, value: '${var.project}' }
    - { name: TRAVIS_WORKER_GCE_REGION, value: '${var.region}' }
    - { name: TRAVIS_WORKER_QUEUE_NAME, value: '${var.queue_name}' }
    - { name: TRAVIS_WORKER_AMQP_URI, value: '${var.amqp_uri}' }
    - { name: TRAVIS_WORKER_BUILD_API_URI, value: '${var.build_api_uri}' }

    - { name: TRAVIS_WORKER_GCE_BOOT_POLL_SLEEP, value: 7s }
    - { name: TRAVIS_WORKER_GCE_BOOT_PRE_POLL_SLEEP, value: 5s }
    - { name: TRAVIS_WORKER_GCE_DISK_SIZE, value: 15 }
    - { name: TRAVIS_WORKER_GCE_IMAGE_DEFAULT, value: 'travis-ci-garnet-trusty.%2B' }
    - { name: TRAVIS_WORKER_GCE_IMAGE_PROJECT_ID, value: 'travis-worker-standalone' }
    - { name: TRAVIS_WORKER_GCE_MACHINE_TYPE, value: 'n1-standard-2' }
    - { name: TRAVIS_WORKER_GCE_SKIP_STOP_POLL, value: 'true' }
    - { name: TRAVIS_WORKER_GCE_UPLOAD_RETRIES, value: 300 }
    - { name: TRAVIS_WORKER_INFRA, value: gce }
    - { name: TRAVIS_WORKER_OPENCENSUS_TRACING_ENABLED, value: 'true' }
    - { name: TRAVIS_WORKER_POOL_SIZE, value: 30 }
    - { name: TRAVIS_WORKER_PPROF_PORT, value: 6060 }
    - { name: TRAVIS_WORKER_PROVIDER_NAME, value: gce }
    - { name: TRAVIS_WORKER_SCRIPT_UPLOAD_TIMEOUT, value: 7m }
    - { name: TRAVIS_WORKER_STARTUP_TIMEOUT, value: 8m }
    - { name: GOTRACEBACK, value: all }
  restartPolicy: Always
EOF
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
#    "user-data"                 = "${data.template_file.worker_cloud_config.rendered}"
    "gce-container-declaration" = "${data.template_file.worker_container_config.rendered}"
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
  base_instance_name = "worker"
  instance_template  = "${google_compute_instance_template.worker.self_link}"
  name               = "worker"
  target_size        = "${var.worker_managed_instance_count}"
  update_strategy    = "NONE"
  region             = "${var.region}"

  distribution_policy_zones = "${formatlist("${var.region}-%s", var.zones)}"
}

output "worker_service_account_email" {
  value = "${google_service_account.worker.email}"
}
