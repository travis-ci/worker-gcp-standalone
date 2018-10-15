#cloud-config
# vim:filetype=yaml

bootcmd:
- curl -sSL https://get.docker.io | bash

users:
- travis

write_files:
- content: '${base64encode(worker_config)}'
  encoding: b64
  owner: 'travis:travis'
  path: /etc/default/travis-worker
- content: '${base64encode(cloud_init_env)}'
  encoding: b64
  owner: 'travis:travis'
  path: /etc/default/travis-worker-cloud-init
- content: '${base64encode(file("${assets}/travis-worker-wrapper"))}'
  encoding: b64
  owner: 'root:root'
  path: /usr/local/bin/travis-worker-wrapper
  permissions: '0755'
- content: '${base64encode(gce_account_json)}'
  encoding: b64
  owner: 'travis:travis'
  path: /var/tmp/gce.json
- content: '${base64encode(file("${assets}/cloud-init.bash"))}'
  encoding: b64
  path: /var/lib/cloud/scripts/per-instance/99-travis-worker-cloud-init
  permissions: '0750'
- content: '${base64encode(file("${assets}/travis-worker.service"))}'
  encoding: b64
  owner: 'root:root'
  path: /var/tmp/travis-worker.service
