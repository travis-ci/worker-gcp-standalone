# worker-gcp-standalone

This is a terraform config that runs a worker in a setup that is similar to our hosted production setup ([travis-ci/terraform-config](https://github.com/travis-ci/gcloud-cleanup)) -- though it is a simplified version that makes less assumptions about the rest of the system.

The main audience for this repo are enterprise users who would like to run their own workers on google cloud.

## How it works

### High-level flow

In this setup there is a managed instance group of worker hosts. Each of the hosts runs one worker, which connects to RabbitMQ.

Worker consumes jobs from the configured queue, `builds.trusty` by default.

For each job, it will boot a new VM, run the job in that VM, stream the logs back to RabbitMQ.

### Limitations

There are some things that are present in our production setup, which are not included here:

* NAT: We do not support NATing. Each job instance will get an ephemeral public IP. Ingress traffic is disallowed.

* Cleanup: We do not run [`gcloud-cleanup`](https://github.com/travis-ci/gcloud-cleanup), which means leaked VMs (e.g. from crashed workers) can persist. You may need to clean those up yourself.

* Job Board: We do not run [`job-board`](https://github.com/travis-ci/job-board) for dynamic image selection. Images are configured through environment variables instead.

* Rate Limits: We do not rate-limit traffic to the GCP API, if you run into quota limits, apply for a quota increase from GCP.

* Warmer: We do not support pre-booting of VMs via the [`warmer` service](https://github.com/travis-ci/warmer).

We may support some of these in the future if there is demand.

### Infra

Worker runs as part of a [managed instance group](https://cloud.google.com/compute/docs/instance-groups/#managed_instance_groups). This instance group is responsible for creating machines from an instance template.

By using a managed instance group, it's possible to scale the number of worker hosts for both capacity as well as redundancy.

Each worker host runs a worker process inside a docker container.

### Worker

The [worker](https://github.com/travis-ci/worker) is our job execution engine. It supports various backends as well as a wide array of configuration variables.

### Config

This section will present a subset of what can be configured in worker. More customization is possible.

#### Google Cloud

When running worker on google cloud, you will want to select the google cloud backend provider:

```
export TRAVIS_WORKER_PROVIDER_NAME=gce
```

This provider needs to know where to run the jobs:

```
export TRAVIS_WORKER_GCE_PROJECT_ID=${var.project}
export TRAVIS_WORKER_GCE_REGION=${var.region}
export TRAVIS_WORKER_GCE_ZONE=<generated>
```

There are lots of other things that can be configured too:

```
export TRAVIS_WORKER_GCE_ACCOUNT_JSON=/var/tmp/gce.json
export TRAVIS_WORKER_GCE_MACHINE_TYPE=n1-standard-2
export TRAVIS_WORKER_GCE_DISK_SIZE=15
export TRAVIS_WORKER_GCE_IMAGE_DEFAULT=travis-ci-garnet-trusty.%2B

export TRAVIS_WORKER_GCE_BOOT_POLL_SLEEP=7s
export TRAVIS_WORKER_GCE_BOOT_PRE_POLL_SLEEP=5s
export TRAVIS_WORKER_GCE_UPLOAD_RETRIES=300

export TRAVIS_WORKER_GCE_SKIP_STOP_POLL=true
```

#### Queue

Worker needs to know where to fetch the jobs from, and where to send the logs to.

```
export TRAVIS_WORKER_QUEUE_NAME=${var.queue_name}
export TRAVIS_WORKER_AMQP_URI=${var.amqp_uri}
```

#### Build

Worker needs to know how to generate the build script. It uses the [`build`](https://github.com/travis-ci/travis-build) service for that, which runs as part of the enterprise installation.

```
export TRAVIS_WORKER_BUILD_API_URI=${var.build_api_uri}
```

#### Pool

Worker runs a set of concurrent processors. The number of processors is called the pool size. This is effectively your concurrency per worker.

```
export TRAVIS_WORKER_POOL_SIZE=30
```

If you need more capacity, consider adding more worker hosts instead of increasing the pool size.

#### Timeouts

In addition to the GCE-specific timeouts, there are also some overall ones.

```
export TRAVIS_WORKER_SCRIPT_UPLOAD_TIMEOUT=7m
export TRAVIS_WORKER_STARTUP_TIMEOUT=8m
```

#### Diagnostics

For diagnostics and debugging it is helpful to enable pprof, so that you can grab stack dumps, profiles, and more, via [`go tool pprof`](https://golang.org/pkg/runtime/pprof/).

```
export TRAVIS_WORKER_INFRA=gce
export TRAVIS_WORKER_PPROF_PORT=6060
export GOTRACEBACK=all
```

## Usage

### Setup

```
terraform init
```

### Run

```
terraform plan
terraform apply
```
