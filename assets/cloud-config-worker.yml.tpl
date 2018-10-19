#cloud-config
# vim:filetype=yaml

write_files:
- path: /etc/default/travis-worker
  encoding: b64
  content: ${base64encode(config)}
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
    ExecStart=/usr/bin/docker run --rm --env-file /etc/default/travis-worker --name=travis-worker ${docker_image}
    ExecStop=/usr/bin/docker stop travis-worker
    ExecStopPost=/usr/bin/docker rm travis-worker

runcmd:
- echo ForwardToConsole=yes >> /etc/systemd/journald.conf
- systemctl restart systemd-journald
- systemctl daemon-reload
- systemctl start travis-worker.service
