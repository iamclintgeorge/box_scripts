<div align="center">
  <a href="https://frappe.io">
    <img src=".github/logo.svg" height="80" width="80" alt="Frappe Box Logo">
  </a>
  <h2>Frappe Box Scripts</h2>

**Scripts for Frappe Box**

</div>

> [!Warning]  
> Frappe Box is in beta. It is strongly advised to use with caution.


## File structure

```text
├── /usr/local/bin/
│              ├── configurator-init.sh
│              ├── disk_confirm_server.py
│              ├── setup_zfs.sh
│              └── zpool-check.sh
├── /etc/nginx/sites-available/
│              └── frappe.local
├── /etc/systemd/
│        ├── frappe-stack.target
│        ├── frappe-user.service
│        └── zpool-check.service
└── /home/<user>/.config/container/systemd/
                                   └── * (For rootless user, paste files from quadlet/ here)
```
