#cloud-config
# vim:filetype=yaml

users:
- name: travis
  uid: 2000

# TODO gce-container-declaration
# https://github.com/GoogleCloudPlatform/konlet
write_files:
- path: /etc/default/travis-worker
  encoding: b64
  content: ${base64encode(worker_config)}
- path: /etc/systemd/system/travis-worker.service
  permissions: 0644
  owner: root
  content: |
    [Unit]
    Description=Travis Worker
    Wants=gcr-online.target
    After=gcr-online.target

    [Service]
    ExecStart=/usr/bin/docker run --rm -u 2000 --env-file /etc/default/travis-worker --name=travis-worker ${worker_docker_self_image}
    ExecStop=/usr/bin/docker stop travis-worker
    ExecStopPost=/usr/bin/docker rm travis-worker

runcmd:
- systemctl daemon-reload
- systemctl start travis-worker.service
