#cloud-config
# vim:filetype=yaml

write_files:
- path: /etc/default/gcloud-cleanup
  encoding: b64
  content: ${base64encode(config)}
- path: /etc/systemd/system/gcloud-cleanup.service
  permissions: 0644
  owner: root
  content: |
    [Unit]
    Description=Gcloud Cleanup
    Wants=network-online.target
    After=network-online.target

    [Service]
    Restart=always
    ExecStart=/usr/bin/docker run --rm --env-file /etc/default/gcloud-cleanup --name=gcloud-cleanup ${docker_image}
    ExecStop=/usr/bin/docker stop gcloud-cleanup
    ExecStopPost=/usr/bin/docker rm gcloud-cleanup

runcmd:
- echo ForwardToConsole=yes >> /etc/systemd/journald.conf
- systemctl restart systemd-journald
- systemctl daemon-reload
- systemctl start gcloud-cleanup.service
