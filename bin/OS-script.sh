#!/bin/bash


# ===== Frappe_docker setup =====

# ===== .bashrc =====

# ===== /usr/local/bin scripts =====

# ===== systemd services =====

# ===== This is for Quadlets  =====
# 1. Update the .container file if needed
cp ./new_config.container /etc/containers/systemd/myapp.container

# 2. Tell systemd to regenerate the service from the Quadlet
sudo systemctl daemon-reload

# 3. Start or restart the service
sudo systemctl restart myapp.service
