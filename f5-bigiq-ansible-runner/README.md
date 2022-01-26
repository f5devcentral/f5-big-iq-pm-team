Installation instructions
-------------------------

To be able to run other containers on BIG-IQ version 8.0+, you will need to disable the http-proxy in docker config on BIG-IQ.

```
docker info | grep HTTP
mv /etc/systemd/system/docker.service.d/http-proxy.conf /etc/systemd/system/docker.service.d/http-proxy.conf.disabled
systemctl stop docker
systemctl daemon-reload
systemctl start docker
docker info | grep HTTP    
docker run hello-world
```

Then download the Dockerfile and build the container which will contain ansible and all necessary dependencies.

```
bash
mkdir -p /shared/scripts/ansible
cd /shared/scripts/ansible
curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-ansible-runner/Dockerfile > Dockerfile
docker build -t f5-ansible-runner .
docker run f5-ansible-runner ansible-playbook --version
```

**Note**: Use at your own risk. Running containers on BIG-IQ is not supported by F5. 

Usage
-----

Here is an example of a playbook to run. Note the server IP address is the BIG-IQ IP address defined in the docker0 network interface.

``vi /shared/scripts/ansible/playbook.yml``

```
---
- hosts: all
  connection: local
  vars:
    provider:
      user: admin
      server: 10.100.0.1 # use BIG-IQ IP address defined in ifconfig docker0
      server_port: 443
      password: secret
      auth_provider: tmos
      validate_certs: false

  tasks:
      - name: Example using bigiq_as3_device_disaster_recovery
        include_role:
          name: f5devcentral.bigiq_as3_device_disaster_recovery
        vars:
          dir_as3: /ansible/tmp # the tmp folder will be saved on the BIG-IQ under /shared/scripts/ansible
          bigip1_target: 10.1.1.7 # BIG-IP device
          bigip2_target: 10.1.1.8 # BIG-IP device part of the same HA cluster
          device_username: admin # BIG-IP device user
          device_password: secret # BIG-IP device password
          device_port: 443  # BIG-IP device port
        register: status
```

Execute the ansible playbook as below. Note we are mounting the ``/shared/scripts/ansible`` folder in the docker container ``/ansible`` folder.

```
cd /shared/scripts/ansible
docker run -it -v $(pwd):/ansible f5-ansible-runner 
cd /ansible
ansible-playbook -i nohost, playbook.yml
```