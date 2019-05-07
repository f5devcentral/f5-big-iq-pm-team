**UNDER DEVELOPMENT**

BIG-IQ Onboarding with Docker and Ansible
-----------------------------------------

1. Choose your configuration:

    - small: 1 BIG-IQ CM standalone, 1 BIG-IQ DCD
    - medium: 1 BIG-IQ CM standalone, 2 BIG-IQ DCD
    - large: 2 BIG-IQ CM HA, 3 BIG-IQ DCD

2. Deploy BIG-IQ images in your environment

    - [AWS](https://aws.amazon.com/marketplace/pp/B00KIZG6KA?qid=1495059228012&sr=0-1&ref_=srh_res_product_title)
    - [Azure](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/f5-networks.f5-big-iq?tab=Overview)
    - [VMware](https://downloads.f5.com/esd/eula.sv?sw=BIG-IQ&pro=big-iq_CM&ver=6.1.0&container=v6.1.0&_ga=2.95373976.584487124.1557161462-1415455721.1549652512)
    - [Openstack](https://downloads.f5.com/esd/eula.sv?sw=BIG-IQ&pro=big-iq_CM&ver=6.1.0&container=v6.1.0&_ga=2.200814506.584487124.1557161462-1415455721.1549652512)
    - [HyperV](https://downloads.f5.com/esd/eula.sv?sw=BIG-IQ&pro=big-iq_CM&ver=6.1.0&container=v6.1.0&_ga=2.133130250.584487124.1557161462-1415455721.1549652512)

  Number of instances to bring up:

    - small: 2 BIG-IQ instances
    - medium: 3 BIG-IQ instances
    - large: 5 BIG-IQ instances

3. From any linux machine, clone the repository

```
git clone https://github.com/f5devcentral/f5-big-iq-pm-team.git
```

4. Update the ansible inventory files with the correct information (management IP, self IP, BIG-IQ license, master key, ...)

```
cd f5-big-iq-pm-team/f5-bigiq-onboarding
```

- small:

```
vi inventory/group_vars/bigiq-cm-01.yml
vi inventory/group_vars/bigiq-dcd-01.yml
vi inventory/hosts
```

- medium:

```
vi inventory/group_vars/bigiq-cm-01.yml
vi inventory/group_vars/bigiq-dcd-01.yml
vi inventory/group_vars/bigiq-dcd-02.yml
vi inventory/hosts
```

- large:

```
vi inventory/group_vars/bigiq-cm-01.yml
vi inventory/group_vars/bigiq-cm-02.yml
vi inventory/group_vars/bigiq-dcd-01.yml
vi inventory/group_vars/bigiq-dcd-02.yml
vi inventory/group_vars/bigiq-dcd-03.yml
vi inventory/hosts
```

5. Build the Ansible docker images containing the F5 Ansible Galaxy roles

```
docker build . -t f5-bigiq-onboarding
```

  Test:

```
docker run -t f5-bigiq-onboarding ansible-playbook --version
```

6. Execute the BIG-IQ onboarding playbooks depending on your configuration

- small:

```
./ansible_helper play playbooks/bigiq_onboard_small_standalone_1dcd.yml -i inventory/hosts
```

- medium:

```
./ansible_helper play playbooks/bigiq_onboard_medium_standalone_2dcd.yml -i inventory/hosts
```

- large:

```
./ansible_helper play playbooks/bigiq_onboard_large_ha_3dcd.yml -i inventory/hosts
```

7. Open BIG-IQ CM in a web browser by using the management private or public IP address with https, for example: ``https://<bigiq_mgt_ip>``


Miscellaneous
-------------

- In case you need to restore the BIG-IQ system to factory default settings, follow [K15886 article](https://support.f5.com/csp/article/K15886).

- Enable bash shell by default for admin user:

```
tmsh modify auth user admin shell bash
```

- Enable basic authentication (**lab only**):

 ```
 set-basic-auth on
 ```

- Disable SSL authentication (**lab only**):

```
echo >> /var/config/orchestrator/orchestrator.conf
echo 'VALIDATE_CERTS = "no"' >> /var/config/orchestrator/orchestrator.conf
bigstart restart gunicorn``
```