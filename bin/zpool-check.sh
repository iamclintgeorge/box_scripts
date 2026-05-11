#!/bin/bash

if ! zpool list mypool &>/dev/null; then 
	echo "[zpool-check] NO POOL FOUND: External SSD not detected. Please reconnect and reboot."
	echo "[zpool-check] Attempting to create ZFS Pool ..." 
	/usr/local/bin/setup-zfs.sh
fi

# FIXME: This could maybe cause problem when adding addiional SSDs in RAIDZ1 config
# Check pool health
HEALTH=$(zpool list -H -o health mypool)
if [ "$HEALTH" != "ONLINE" ]; then 
	echo "[zpool-check] POOL DEGRADED: Storage pool is $HEALTH. Check SSD connections."
fi

# Check required datasets
for ds in mysql my-bench; do 
	if ! zfs list mypool/$ds &>/dev/null; then 
		echo "[zpool-check] MISSING DATASETS: Dataset mypool/$ds missing. Run setup again." 
	fi
done

echo "[zpool-check] ZFS successfully detected"
exit 0




# FIXME: Delete the dead code in the future
# Wait for /mypool to be available, timeout after 30s
# for i in $(seq 1 30); do
#     if zpool status mypool &>/dev/null && mountpoint -q /mypool; then
#         echo "mypool is ready"
#         exit 0
#     fi
#     echo "Waiting for mypool... ($i/30)"
#     sleep 1
# done
# echo "mypool not available — skipping Frappe stack"
# exit 0  # exit 0 so it doesn't crash other services
