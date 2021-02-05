Installation instructions
-------------------------

[K15612: Connectivity requirements for the BIG-IQ system](https://support.f5.com/csp/article/K15612)

1. Use SSH to log in as root to your primary BIG-IQ CM.

2. From the command line on the primary BIG-IQ CM, type the following 4 commands.

```
bash
mkdir /shared/scripts
cd /shared/scripts
curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-connectivityChecks/f5_network_connectivity_checks.sh > f5_network_connectivity_checks.sh
chmod +x f5_network_connectivity_checks.sh
```

This command sequence:
a. Starts Bash.
b. Creates a folder for the script.
c. Navigates to the new folder.
d. Copies the script to the new folder.


3. Type the following command to start the script.

```
./f5_network_connectivity_checks.sh [<BIG-IP sshuser> <BIG-IQ sshuser> <~/.ssh/bigip_priv_key> <~/.ssh/bigiq_priv_key>]
```

Note: If your devices require keys for SSH access, use the optional script variables to supply those keys to the script.

The script begins a series of prompts and responses. For each prompt, you respond with an IP address and the
script responds by confirming that there is a connection path from the BIG-IQ to that address.

4. Respond to each script prompt with the IP address of the component that is being queried.
