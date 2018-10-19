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
    ExecStart=/usr/bin/docker run --rm -p 6060:6060 --env-file /etc/default/travis-worker --name=travis-worker ${docker_image}
    ExecStop=/usr/bin/docker stop travis-worker
    ExecStopPost=/usr/bin/docker rm travis-worker
- path: /etc/honeytail/honeytail.conf
  encoding: b64
  content: ${base64encode(honeytail_config)}

runcmd:
- echo ForwardToConsole=yes >> /etc/systemd/journald.conf
- systemctl restart systemd-journald

- wget -q -O /etc/systemd/system/honeytail.service https://raw.githubusercontent.com/honeycombio/honeytail/master/honeytail.service
- wget -q -O /usr/bin/honeytail https://honeycomb.io/download/honeytail/linux/1.683
- chmod +x /usr/local/bin/honeytail

- systemctl daemon-reload
- systemctl start travis-worker.service
- systemctl start honeytail.service
