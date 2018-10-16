# worker-gcp-standalone

This is a terraform config that runs a worker in a setup that is similar to our hosted production setup ([travis-ci/terraform-config](https://github.com/travis-ci/gcloud-cleanup)) -- though it is a simplified version that makes less assumptions about the rest of the system.

The main audience for this repo are enterprise users who would like to run their own workers on Google Cloud.

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

All of this configuration is handled by the terraform setup (see [Usage](#Usage)). You do not need to do any of this manually.

#### Google Cloud

When running worker on Google Cloud, you will want to select the Google Cloud backend provider:

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

You can use this repository to create and maintain your own set of workers running in Google Cloud.

### Setup

First of all, you'll need to clone the repo:

```
git clone https://github.com/travis-ci/worker-gcp-standalone
cd worker-gcp-standalone
```

Next, you will need to [install terraform](https://www.terraform.io/downloads.html):

```
# on macOS
brew install terraform
```

To authenticate the google provider, you should also [install the Google Cloud SDK](https://cloud.google.com/sdk/install), which includes the `gcloud` command-line tool.

```
# on macOS
brew tap caskroom/cask
brew cask install google-cloud-sdk
```

In order to authenticate with your Google Cloud account, you can run:

```
gcloud config set project <project>
gcloud auth application-default login
```

This is needed by later stages.

### Config

Next up, you'll need to configure the variables used by terraform and worker:

```
cp config.auto.tfvars.example config.auto.tfvars
vim config.auto.tfvars
```

* `project` is the name of your Google Cloud project.
* `amqp_uri` is the URI to your RabbitMQ instance.
* `build_api_uri` is the URI to your Travis CI Enterprise's `travis-build` installation.

It is also recommended that you set up a Google Cloud Storage bucket and configure terraform to persist its state there.

```
cp backend.tf.example backend.tf
vim backend.tf
```

This step is optional. As a fallback, terraform will store the state on your local machine.

Once the configuration is complete, you can go ahead and initialize terraform:

```
terraform init
```

### Run

Once everything is configured and initialized, you can go ahead and run a `plan`, to see what terraform is about to create:

```
terraform plan
```

It should spit out a large blob of text, with a plan to create an instance template, an instance group, and possibly more.

To actually create those resources, you can run `apply`:

```
terraform apply
```

This will create the managed instance group and boot a worker.

You can look at the list of instance groups to see if it was created properly. By clicking on the `worker` instance group, you should also see a worker host with a name like `worker-<suffix>`, e.g. `worker-0crc`.

After clicking on that worker instance, you can click on `Serial port 1 (console)` to see the boot log. After a few minutes of boot time, you should see something along the lines of:

```
Oct 16 10:50:44 worker-0crc travis-worker[4071]: time="2018-10-16T10:50:44Z" level=info msg=starting pid=1 self=cli
Oct 16 10:50:44 worker-0crc travis-worker[4071]: time="2018-10-16T10:50:44Z" level=info msg="worker started" pid=1 self=cli
Oct 16 10:50:44 worker-0crc travis-worker[4071]: time="2018-10-16T10:50:44Z" level=info msg="setting up heartbeat" pid=1 self=cli
Oct 16 10:50:44 worker-0crc travis-worker[4071]: time="2018-10-16T10:50:44Z" level=info msg="starting signal handler loop" pid=1 self=cli
Oct 16 10:50:44 worker-0crc travis-worker[4071]: time="2018-10-16T10:50:44Z" level=info msg="starting processor" pid=1 processor=197a3e99-bd25-4bfa-802a-6311b3cc71ef@1.worker-0crc self=processor
O
```

This indicates that the worker started successfully.

### Making changes

When making changes to the config, rolling out the change requires a few steps.

First, you need to `plan`:

```
terraform plan
```

If the proposed changes look good, you can `apply`:

```
terraform apply
```

This will update the instance template, it will however not touch any of the existing instances.

To make the changes live, the existing instances need to be replaced. That can be done via the `gcloud` tool on the command line (`region` would be something like `us-central1`):

```
gcloud beta compute instance-groups managed rolling-action replace worker --max-surge=4 --max-unavailable=4 --region <region> --project <project>
```

This will delete the existing worker instances and create new ones to replace them.

Note that this can affect running jobs, so if possible, you should schedule a maintenance window for this operation and stop any running jobs before doing this.

### Cleanup

Since it is possible that jobs do not get cleaned up properly, you can use this command to find and delete old instances:

```
gcloud compute instances list \
  --filter="creationTimestamp<$(ruby -r time -e 'puts (Time.now.utc - 2*3600).iso8601') AND name:travis-job-*" \
  --format=json \
  --project <project> \
  | jq -r '.[].selfLink' \
  | xargs -n1 -I'{}' gcloud compute instances delete --quiet {} --project <project>
```

You'll need to install [`jq`](https://stedolan.github.io/jq/) (`brew install jq`), and replace `<project>` with the name of your Google Cloud project.
