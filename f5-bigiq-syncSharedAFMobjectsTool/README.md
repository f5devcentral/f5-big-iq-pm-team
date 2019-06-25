Installation instructions
-------------------------

```
# mkdir /shared/scripts
# cd /shared/scripts
# curl https://raw.githubusercontent.com/f5devcentral/f5-big-iq-pm-team/master/f5-bigiq-syncSharedAFMobjectsTool/sync-shared-afm-objects.sh > sync-shared-afm-objects.sh
# chmod +x sync-shared-afm-objects.sh
```

Usage
-----

```
# cd /shared/scripts
# ./sync-shared-afm-objects.sh <big-iq-ip-target> admin password >> /shared/scripts/sync-shared-afm-objects.log
```