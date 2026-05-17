## File structure
├── /usr/local/bin/
│              ├── configurator-init.sh
│              ├── disk_confirm_server.py
│              ├── setup_zfs.sh
│              ├── zpool-check.sh
├── /etc/nginx/sites-available/
│              ├── frappe.local
├── /etc/systemd/
│        ├── frappe-stack.target
│        ├── frappe-user.service
│        ├── zpool-check.service
└── home/<user>/.config/container/systemd/* (For rootless user, paste files from quadlet/ here)
