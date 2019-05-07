**UNDER DEVELOPMENT**

BIG-IQ Onboarding with Docker and Ansible
-----------------------------------------

1. Choose your configuration:

    - Small: 1 BIG-IQ CM standalone, 1 BIG-IQ DCD
    - Medium: 1 BIG-IQ CM standalone, 2 BIG-IQ DCD
    - Large: 2 BIG-IQ CM HA, 3 BIG-IQ DCD

2. Deploy BIG-IQ images in your environment.

    - [AWS](https://aws.amazon.com/marketplace/pp/B00KIZG6KA?qid=1495059228012&sr=0-1&ref_=srh_res_product_title)
    - [Azure](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/f5-networks.f5-big-iq?tab=Overview)
    - [VMware](https://downloads.f5.com/esd/eula.sv?sw=BIG-IQ&pro=big-iq_CM&ver=6.1.0&container=v6.1.0&_ga=2.95373976.584487124.1557161462-1415455721.1549652512)
    - [Openstack](https://downloads.f5.com/esd/eula.sv?sw=BIG-IQ&pro=big-iq_CM&ver=6.1.0&container=v6.1.0&_ga=2.200814506.584487124.1557161462-1415455721.1549652512)
    - [HyperV](https://downloads.f5.com/esd/eula.sv?sw=BIG-IQ&pro=big-iq_CM&ver=6.1.0&container=v6.1.0&_ga=2.133130250.584487124.1557161462-1415455721.1549652512)

    Number of instances to bring up:

    - small: **2** BIG-IQ instances
    - medium: **3** BIG-IQ instances
    - large: **5** BIG-IQ instances

    Public Cloud deployments ([AWS](https://techdocs.f5.com/kb/en-us/products/big-iq-centralized-mgmt/manuals/product/big-iq-centralized-management-and-amazon-web-services-setup-6-0-0.html)/[Azure](https://techdocs.f5.com/kb/en-us/products/big-iq-centralized-mgmt/manuals/product/big-iq-centralized-management-and-msft-azure-setup-6-0-0.html)):

    - Deploy the instances with min 2 NICs (AWS and Azure)
    - Create an EIP and assign it to the primary interface for each instances (AWS)
    - Make sure you have the private key of the Key Pairs selected used by the instances (AWS and Azure)
    - Configure the network security group for the ingress rules on each instances (AWS and Azure)

      Example: (10.1.0.0/16 being the subnet of the BIG-IQ/DCD)

      Ports | Protocol | Source 
      ----- | -------- | ------
      | 80  | tcp      | 0.0.0.0/0 |
      | 443 | tcp      | 0.0.0.0/0 |
      |  22 | tcp      | 0.0.0.0/0 |
      | 1-65356 | tcp  | 10.1.0.0/16 |

    - Set the admin password, SSH to each instances and execute ``modify auth password admin``, ``save sys config`` (AWS and Azure)
  
3. From any linux machine, clone the repository

    Pre-requisists:

    - Install Docker in [AWS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/docker-basics.html) or [others](https://docs.docker.com/install/linux/docker-ce/ubuntu/).
    - Install [Git](https://git-scm.com/download/linux).

    Example for Amazon Linux EC2 instance:
    ```
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo yum install git -y
    ```

    Clone the repository:

    ```
    git clone https://github.com/f5devcentral/f5-big-iq-pm-team.git
    ```

4. Update the ansible inventory files with the correct information (management IP, self IP, BIG-IQ license, master key, ...)

    Public Cloud deployments:
    
    - bigiq_onboard_discovery_address should be removed unless you set a 3rd NIC on a different subnet (AWS and Azure)

  ```
  cd f5-big-iq-pm-team/f5-bigiq-onboarding
  ```

  - if Small selected, edit:

  ```
  vi inventory/group_vars/bigiq-cm-01.yml
  vi inventory/group_vars/bigiq-dcd-01.yml
  vi inventory/hosts
  ```

  - if Medium selected, edit:

  ```
  vi inventory/group_vars/bigiq-cm-01.yml
  vi inventory/group_vars/bigiq-dcd-01.yml
  vi inventory/group_vars/bigiq-dcd-02.yml
  vi inventory/hosts
  ```

  - if Large selected, edit:

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
  sudo docker build . -t f5-bigiq-onboarding
  ```

  Validate Docker and Ansible are working correctly: (Ansible version should be displayed)

  ```
  sudo docker run -t f5-bigiq-onboarding ansible-playbook --version
  ```

6. Execute the BIG-IQ onboarding playbooks.

  - if Small selected, run:

  ```
  ./ansible_helper ansible-playbook /ansible/playbooks/bigiq_onboard_small_standalone_1dcd.yml -i /ansible/inventory/hosts
  ```

  - if Medium selected, run:

  ```
  ./ansible_helper ansible-playbook /ansible/playbooks/bigiq_onboard_medium_standalone_2dcd.yml -i /ansible/inventory/hosts
  ```

  - if Large selected, run:

  ```
  ./ansible_helper ansible-playbook /ansible/playbooks/bigiq_onboard_large_ha_3dcd.yml -i /ansible/inventory/hosts
  ```

7. Open BIG-IQ CM in a web browser by using the management private or public IP address with https, for example: ``https://<bigiq_mgt_ip>``

Miscellaneous
-------------

- In case you need to restore the BIG-IQ system to factory default settings, follow [K15886](https://support.f5.com/csp/article/K15886) article.

- Enable basic authentication (**LAB/POC only**):

 ```
 set-basic-auth on
 ```

- Disable SSL authentication for SSG (**LAB/POC only**):

```
echo >> /var/config/orchestrator/orchestrator.conf
echo 'VALIDATE_CERTS = "no"' >> /var/config/orchestrator/orchestrator.conf
bigstart restart gunicorn``
```

Troubleshooting
---------------

n/a
