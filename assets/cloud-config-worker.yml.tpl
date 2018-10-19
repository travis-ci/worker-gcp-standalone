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
  permissions: 0644
  owner: root
  content: |
    [Application Options]
    SampleRate = ${honeycomb_sample_rate}

    [Required Options]
    ParserName = keyval
    LogFiles = -
    WriteKey = ${honeycomb_writekey}
    Dataset = ${honeycomb_dataset}

    [KeyVal Parser Options]
    TimeFieldName = time
    FilterRegex = time=
- path: /etc/systemd/system/honeytail.service
  permissions: 0644
  owner: root
  content: |
    [Unit]
    Description=Honeycomb log tailer honeytail
    After=network.target

    [Service]
    ExecStart=/bin/sh -c '/usr/bin/journalctl -u travis-worker --follow --output=cat | /usr/bin/docker run --rm -i -v /etc/honeytail/honeytail.conf:/etc/honeytail/honeytail.conf --name=honeytail travisci/honeytail:latest honeytail -c /etc/honeytail/honeytail.conf --add_field app=worker --add_field hostname=%H'
    ExecStop=/usr/bin/docker stop honeytail
    ExecStopPost=/usr/bin/docker rm honeytail
    Restart=on-failure

    [Install]
    Alias=honeytail honeytail.service

runcmd:
- echo ForwardToConsole=yes >> /etc/systemd/journald.conf
- systemctl restart systemd-journald

- wget -q -O /usr/bin/honeytail https://honeycomb.io/download/honeytail/linux/1.683
- chmod +x /usr/bin/honeytail

- systemctl daemon-reload
- systemctl start travis-worker.service
- '[[ -z "${honeycomb_dataset}" ]] || systemctl start honeytail.service'
