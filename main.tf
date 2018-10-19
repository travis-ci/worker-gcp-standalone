variable "amqp_uri" {}
variable "build_api_uri" {}

variable "cos_image" {
  default = "cos-cloud/cos-stable"
}

variable "honeycomb_dataset" {
  default = ""
}

variable "honeycomb_writekey" {
  default = ""
}

variable "honeycomb_sample_rate" {
  default = "1"
}

variable "machine_type" {
  default = "n1-standard-1"
}

variable "project" {}

variable "queue_name" {
  default = "builds.trusty"
}

variable "region" {
  default = "us-central1"
}

variable "zones" {
  default = ["a", "b", "c", "f"]
}

provider "google" {
  project = "${var.project}"
  region  = "${var.region}"
}
