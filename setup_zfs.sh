#!/bin/bash

cat << 'EOF'

███████╗██████╗  █████╗ ██████╗ ██████╗ ███████╗    ██████╗  ██████╗ ██╗  ██╗
██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝    ██╔══██╗██╔═══██╗╚██╗██╔╝
█████╗  ██████╔╝███████║██████╔╝██████╔╝█████╗      ██████╔╝██║   ██║ ╚███╔╝
██╔══╝  ██╔══██╗██╔══██║██╔═══╝ ██╔═══╝ ██╔══╝      ██╔══██╗██║   ██║ ██╔██╗
██║     ██║  ██║██║  ██║██║     ██║     ███████╗    ██████╔╝╚██████╔╝██╔╝ ██╗
╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═╝

EOF

# Logic:
# FIXME: Add conditional logic to first check if zpool mountpoint mypool/my-bench exists or not. If it exists then directly focus on running frappe bench
# FIXME: If zpool mountpoint exists + disk in lsblk which is not part of zpool then initiate process to create RAID Z1 config.


SIGNAL_FILE="/tmp/disk_confirm_result"
SERVER_SCRIPT="$(dirname "$0")/disk_confirm_server.py"
CONFIRM_PORT=8765
POLL_INTERVAL=2
TIMEOUT=300  # 5 minutes before auto-abort


# ===== Scan for disks =====
echo "[zfs-setup] Scanning for available disks..."

RAW_JSON=$(lsblk -J -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL,SERIAL,ROTA,RO)

# JSON array for the confirmation UI
DISK_JSON=$(echo "$RAW_JSON" | jq '[
  .blockdevices[]
  | select(
      .type == "disk"
      and .rota == true
      and .mountpoint == null
      and (all(.children[]?; .mountpoint == null))
      and .ro == false
      and (.size | test("G|T"))
      and (.name | contains("mmcblk") | not)
    )
  | {
      path:   ("/dev/" + .name),
      size:   .size,
      model:  (.model // "Unknown"),
      serial: (.serial // null),
      fstype: (.fstype // null),
      rota:   .rota
    }
]')

# Plain /dev/path list for the wipe loop
DISK_PATHS=$(echo "$DISK_JSON" | jq -r '.[].path')

if [ -z "$DISK_PATHS" ]; then
  echo "[zfs-setup] No eligible disks found. Exiting."
  exit 1
fi

DISK_COUNT=$(echo "$DISK_PATHS" | wc -l)
echo "[zfs-setup] Found $DISK_COUNT disk(s):"
echo "$DISK_PATHS" | sed 's/^/  /'


# ===== Lauch Confirmation UI =====
rm -f "$SIGNAL_FILE"

python3 "$SERVER_SCRIPT" "$DISK_JSON" "$SIGNAL_FILE" &
SERVER_PID=$!

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Waiting for confirmation at http://frappe.local/disk-confirm  ║"
echo "║  Open your browser and confirm or cancel the disk wipe.        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""


ELAPSED=0
while [ ! -f "$SIGNAL_FILE" ]; do
  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "[zfs-setup] Timed out waiting for confirmation. Aborting."
    kill "$SERVER_PID" 2>/dev/null
    exit 1
  fi
done

CHOICE=$(cat "$SIGNAL_FILE")
rm -f "$SIGNAL_FILE"

# Wait for Python server to finish shutting itself down
wait "$SERVER_PID" 2>/dev/null

echo "[zfs-setup] User responded: $CHOICE"

if [ "$CHOICE" != "yes" ]; then
  echo "[zfs-setup] Aborted by user. No changes made."
  exit 0
fi


# ===== Wipe disk =====
echo ""
echo "[zfs-setup] Proceeding with disk wipe..."

for d in $DISK_PATHS; do
    echo "[zfs-setup] Wiping $d ..."
    # Clear ZPool Labels (If Present)
    zpool labelclear -f "$d" || true
    wipefs -a "$d"
    partprobe "$d"
done

echo "[zfs-setup] All disks wiped."


# ===== Create ZFS Pool =====
echo "[zfs-setup] Creating ZFS pool 'mypool'..."
zpool create -o ashift=12 mypool $DISK_PATHS
echo "[zfs-setup] ZFS pool 'mypool' created successfully."

echo "[zfs-setup] Creating ZFS pool datasets..."
sudo zfs create -o recordsize=16k mypool/sql
sudo zfs create mypool/my-bench

# MariaDB - ZFS specific configuration optimization
# sudo zfs set primarycache=metadata mypool/sql
# sudo zfs set logbias=throughput mypool/sql
# sudo zfs set redundant_metadata=most mypool/sql

sudo chown -R frappe:frappe /mypool
sudo chown -R frappe:frappe /mypool/my-bench /mypool/sql
sudo chmod -R 775 /mypool/my-bench /mypool/sql
echo "[zfs-setup] ZFS pool datasets created successfully."


# Move container images to zpool datasets
echo "[zfs-setup] Moving container data to /mypool ..."
sudo rsync -av ~/.local/share/containers/storage/volumes/frappe_docker_db-data/_data/ /mypool/sql/
podman cp frappe_docker-backend-1:/home/frappe/frappe-bench/sites/. /mypool/my-bench/

podman unshare chown -R 999:999 /mypool/sql
podman unshare chown -R 1000:1000 /mypool/my-bench

# FIXME: This is a temporary fix. This code in unsafe for Production
podman exec systemd-db mariadb -u root --password=123 -e "UPDATE mysql.user SET Host='%' WHERE User != 'root' AND Host != 'localhost'; FLUSH PRIVILEGES;"

echo "[zfs-setup] Container data moved to /mypool datasets successfully."

# Initial ZFS Snapshot
# sudo zfs snapshot mypool/sql@initial
# sudo zfs snapshot mypool/my-bench@initial

# Start frappe setup
echo "[zfs-setup] Start Frappe Service"
systemctl --user start db.service redis-cache.service redis-queue.service configurator.service backend.service websocket.service frontend.service queue-long.service queue-short.service scheduler.service
