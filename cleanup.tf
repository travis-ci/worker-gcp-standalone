variable "cleanup_docker_self_image" {
  default = "travisci/gcloud-cleanup:c636f91"
}

variable "cleanup_instance_max_age" {
  default = "3h"
}

variable "cleanup_loop_sleep" {
  default = "1m"
}

variable "cleanup_managed_instance_count" {
  default = "1"
}

resource "google_service_account" "cleanup" {
  account_id   = "cleanup"
  display_name = "Gcloud Cleanup"
  project      = "${var.project}"
}

resource "google_project_iam_custom_role" "cleanup" {
  role_id     = "cleanup"
  title       = "Gcloud Cleaner"
  description = "A gcloud-cleanup process that can clean and archive stuff"

  permissions = [
    "cloudtrace.traces.patch",
    "compute.disks.delete",
    "compute.disks.get",
    "compute.disks.list",
    "compute.disks.update",
    "compute.globalOperations.get",
    "compute.globalOperations.list",
    "compute.images.delete",
    "compute.images.get",
    "compute.images.list",
    "compute.instances.delete",
    "compute.instances.deleteAccessConfig",
    "compute.instances.detachDisk",
    "compute.instances.get",
    "compute.instances.getSerialPortOutput",
    "compute.instances.list",
    "compute.instances.reset",
    "compute.instances.stop",
    "compute.instances.update",
    "compute.regions.get",
    "compute.regions.list",
    "compute.zones.get",
    "compute.zones.list",
    "storage.objects.create",
    "storage.objects.update",
  ]
}

resource "google_project_iam_member" "cleanup" {
  project = "${var.project}"
  role    = "projects/${var.project}/roles/${google_project_iam_custom_role.cleanup.role_id}"
  member  = "serviceAccount:${google_service_account.cleanup.email}"
}

data "template_file" "cleanup_cloud_config" {
  template = "${file("${path.module}/assets/cloud-config-cleanup.yml.tpl")}"

  vars {
    docker_image = "${var.cleanup_docker_self_image}"

    config = <<EOF
GCLOUD_CLEANUP_ENTITIES=instances
GCLOUD_CLEANUP_INSTANCE_FILTERS=name eq ^travis-job-.*
GCLOUD_CLEANUP_INSTANCE_MAX_AGE=${var.cleanup_instance_max_age}
GCLOUD_CLEANUP_LOOP_SLEEP=${var.cleanup_loop_sleep}
GCLOUD_CLEANUP_OPENCENSUS_TRACING_ENABLED=true
GCLOUD_PROJECT=${var.project}
EOF
  }
}

resource "google_compute_instance_template" "cleanup" {
  name_prefix = "cleanup-"

  machine_type = "${var.machine_type}"
  tags         = ["cleanup"]
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
    "user-data" = "${data.template_file.cleanup_cloud_config.rendered}"
  }

  lifecycle {
    create_before_destroy = true
  }

  service_account {
    email  = "${google_service_account.cleanup.email}"
    scopes = [
      "cloud-platform",
      "storage-full",
      "compute-rw",
      "trace-append"
    ]
  }
}

resource "google_compute_region_instance_group_manager" "cleanup" {
  base_instance_name = "cleanup"
  instance_template  = "${google_compute_instance_template.cleanup.self_link}"
  name               = "cleanup"
  target_size        = "${var.cleanup_managed_instance_count}"
  update_strategy    = "NONE"
  region             = "${var.region}"

  distribution_policy_zones = "${formatlist("${var.region}-%s", var.zones)}"
}

output "cleanup_service_account_email" {
  value = "${google_service_account.cleanup.email}"
}
