#!/bin/bash

export PATH="$PATH:/home/frappe/.local/bin:/home/frappe/.nvm/versions/node/v24.15.0/bin"

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


# Scan for disks
DISK=$(lsblk -J -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL,SERIAL,ROTA,RO | jq -r '.blockdevices[] | select(.type=="disk" and .rota==true and .mountpoint==null and (all(.children[]?; .mountpoint == null)) and .ro==false and (.size | test("G|T")) and (.name | contains("mmcblk") | not)) | "/dev/" + .name')

if [ -z "$DISK" ]; then
  echo "No valid SSDs found."
  exit 1
fi

echo "Disks Found: $DISK"

# Wipe disk
for d in $DISK; do
	echo "wiping $d ..."
	# Clear zfs labels (if present)
	zpool labelclear -f "$d" || true
	wipefs -a "$d"
	partprobe "$d"
done
echo "Data wiped from all found disks"

# Create zpool
zpool create -o ashift=12 mypool $DISK
echo "Successfully created ZPool"

# Hydrate zfs with seed
sudo sh -c 'zcat /home/frappe/Desktop/my-bench-seed.zfs.gz | zfs receive mypool/my-bench'
zfs set mountpoint=/home/frappe/Desktop/frappe/my-bench mypool/my-bench
echo "Frappe Bench moved to ZPool"

# Run the frappe bench
# Source nvm and find node/npm paths (FIXME: In future it needs to be dynamic in nature)
NODE_PATH=/home/frappe/.nvm/versions/node/v24.15.0/bin/node
NPM_PATH=/home/frappe/.nvm/versions/node/v24.15.0/bin/npm

# Move to using this in the future for Dynamic handling of files (Else, expose whole env to mypool mountpoint)
# NODE_VERSION=$(ls /home/frappe/.nvm/versions/node | sort -V | tail -1)
# NODE_PATH=/home/frappe/.nvm/versions/node/$NODE_VERSION/bin/node
# NPM_PATH=/home/frappe/.nvm/versions/node/$NODE_VERSION/bin/npm

# FIXME: Remove the dead code in the future
#if [ -z "$NODE_PATH" ]; then
#  for p in /usr/local/bin/node /usr/bin/node /opt/node/bin/node; do
#    [ -x "$p" ] && NODE_PATH="$p" && break
#  done
#fi
#
#if [ -z "$NPM_PATH" ]; then
#  for p in /usr/local/bin/npm /usr/bin/npm /opt/node/bin/npm; do
#    [ -x "$p" ] && NPM_PATH="$p" && break
#  done
#fi

echo "Frappe user environment:"
sudo -u frappe -i bash -c 'echo PATH=$PATH; ls $HOME/.nvm/versions/node/ 2>/dev/null || echo "nvm not found"'

if [ -z "$NODE_PATH" ] || [ -z "$NPM_PATH" ]; then
  echo "ERROR: Could not locate node or npm for frappe user. Aborting."
  exit 1
fi

echo "Found node: $NODE_PATH"
echo "Found npm:  $NPM_PATH"

# symlinks
ln -sf "$NODE_PATH" /usr/bin/node
ln -sf "$NPM_PATH" /usr/bin/npm
ln -sf /home/frappe/.nvm/versions/node/v24.15.0/bin/yarn /usr/bin/yarn

# ls -l /usr/bin/node /usr/bin/npm

# Fix permissions on the new mount (for frappe usergroup)
chown -R frappe:frappe /home/frappe/Desktop/frappe/my-bench

sudo -u frappe -i bash -c "cd /home/frappe/Desktop/frappe/my-bench && bench start"
