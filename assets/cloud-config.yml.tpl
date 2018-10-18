#cloud-config
# vim:filetype=yaml

users:
- name: travis
  uid: 2000

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
    Wants=network-online.target
    After=network-online.target

    [Service]
    Restart=always
    ExecStart=/usr/bin/docker run --rm -u 2000 --env-file /etc/default/travis-worker --name=travis-worker ${worker_docker_self_image}
    ExecStop=/usr/bin/docker stop travis-worker
    ExecStopPost=/usr/bin/docker rm travis-worker

runcmd:
- echo ForwardToConsole=yes >> /etc/systemd/journald.conf
- systemctl restart systemd-journald
- systemctl daemon-reload
- systemctl start travis-worker.service
