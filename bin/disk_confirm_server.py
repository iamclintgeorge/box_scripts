#!/usr/bin/env python3
"""
Disk Wipe Confirmation Server
Serves a confirmation UI at port 8765, waits for user response,
then writes result to a signal file that bash polls (IPC Communication).
Usage: python3 disk_confirm_server.py '<JSON disk data>' <signal_file>
"""

import sys
import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

SIGNAL_FILE = sys.argv[2] if len(sys.argv) > 2 else "/tmp/disk_confirm_result"
DISK_JSON   = sys.argv[1] if len(sys.argv) > 1 else "[]"
PORT        = 8765

HTML = """<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Disk Wipe Confirmation</title>
    <style>
      @import url("https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&family=Playfair+Display:ital,wght@0,400..900;1,400..900&family=Poppins:ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;0,800;0,900;1,100;1,200;1,300;1,400;1,500;1,600;1,700;1,800;1,900&display=swap");

      *,
      *::before,
      *::after {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
      }

      :root {
        --bg: #ffffff;
        --border: #252a36;
        --border-hi: #3a4259;
        --text: #e2e8f0;
        --muted: #8892a4;
        --accent: #f97316;
        --accent-lo: rgba(249, 115, 22, 0.12);
        --danger: #ef4444;
        --danger-lo: rgba(239, 68, 68, 0.1);
        --ok: #22c55e;
        --ok-lo: rgba(34, 197, 94, 0.1);
        --mono: "Inter", monospace;
        --display: "Inter", sans-serif;
      }

      html,
      body {
        height: 100%;
        background: var(--bg);
        color: var(--text);
        font-family: var(--mono);
        font-size: 14px;
        line-height: 1.6;
      }

      body {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        padding: 2rem;
        gap: 2rem;
      }

      .header {
        text-align: center;
        max-width: 600px;
      }

      .badge {
        display: inline-block;
        background: var(--accent-lo);
        color: var(--accent);
        border: 1px solid var(--accent);
        border-radius: 4px;
        font-family: var(--mono);
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.15em;
        padding: 3px 10px;
        margin-bottom: 1.25rem;
        text-transform: uppercase;
      }

      h1 {
        font-family: var(--display);
        font-size: 2rem;
        font-weight: 700;
        color: #000000;
        letter-spacing: -0.02em;
        line-height: 1.15;
        margin-bottom: 0.5rem;
      }

      .subtitle {
        color: var(--muted);
        font-size: 15px;
      }

      .disk-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 1rem;
        width: 100%;
        max-width: 860px;
      }

      .disk-card {
        background: var(--bg);
        border: 1px solid var(--border);
        border-radius: 10px;
        padding: 1.25rem;
        position: relative;
        transition: border-color 0.2s;
      }

      .disk-card:hover {
        border-color: var(--border-hi);
      }

      .disk-card::before {
        content: "";
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 2px;
        background: var(--accent);
        border-radius: 10px 10px 0 0;
        opacity: 0.7;
      }

      .disk-name {
        font-family: var(--display);
        font-size: 1.1rem;
        font-weight: 600;
        color: #000000;
        margin-bottom: 0.85rem;
        display: flex;
        align-items: center;
        gap: 0.5rem;
      }

      .disk-name .dev {
        font-family: var(--mono);
        font-size: 0.85rem;
        color: var(--accent);
        background: var(--accent-lo);
        border-radius: 4px;
        padding: 1px 7px;
      }

      .disk-meta {
        display: grid;
        grid-template-columns: auto 1fr;
        gap: 5px 12px;
        font-size: 12px;
      }

      .disk-meta .label {
        color: #000000;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        font-size: 11px;
        align-self: center;
      }

      .disk-meta .value {
        color: #000000;
        font-family: var(--mono);
      }

      .warn-box {
        background: var(--danger-lo);
        border: 1px solid var(--danger);
        border-radius: 8px;
        padding: 1rem 1.25rem;
        max-width: 560px;
        width: 100%;
        text-align: center;
        font-size: 13px;
        color: #e74848;
      }

      .warn-box strong {
        display: block;
        font-family: var(--display);
        font-size: 1rem;
        font-weight: 600;
        color: var(--danger);
        margin-bottom: 0.25rem;
      }

      .actions {
        display: flex;
        gap: 1rem;
        flex-wrap: wrap;
        justify-content: center;
      }

      button {
        font-family: var(--mono);
        font-size: 13px;
        font-weight: 600;
        letter-spacing: 0.08em;
        padding: 0.25rem 0.6rem;
        border-radius: 5px;
        border: 1px solid;
        cursor: pointer;
        transition: all 0.15s;
      }

      .btn-confirm {
        background: var(--danger);
        border-color: var(--danger);
        color: #fff;
      }

      .btn-confirm:hover {
        background: #dc2626;
        transform: translateY(-1px);
      }
      .btn-confirm:active {
        transform: translateY(0);
      }

      .btn-cancel {
        background: transparent;
        border-color: var(--border-hi);
      }

      .btn-cancel:hover {
        border-color: var(--text);
        /* color: var(--text); */
      }

      .status {
        display: none;
        font-family: var(--display);
        font-size: 13px;
        font-weight: 600;
        padding: 0.75rem 0.8rem;
        border-radius: 8px;
        text-align: center;
      }

      .status.ok {
        background: var(--ok-lo);
        color: var(--ok);
        border: 1px solid var(--ok);
      }
      .status.no {
        background: var(--accent-lo);
        color: var(--accent);
        border: 1px solid var(--accent);
      }

      .hostname {
        position: fixed;
        bottom: 1rem;
        right: 1.25rem;
        font-size: 11px;
        color: var(--border-hi);
        letter-spacing: 0.05em;
      }
    </style>
  </head>
  <body>
    <div class="header">
      <!-- <div class="badge">⚠ destructive operation</div> -->
      <h1>Confirm disk wipe</h1>
      <p class="subtitle">
        The following disks will be zeroed and added to a new ZFS pool
      </p>
    </div>

    <div class="disk-grid" id="diskGrid"></div>

    <div class="warn-box">
      <strong>This action is irreversible</strong>
      All data on the listed disks will be permanently destroyed. Confirm only
      if you are sure these disks contain no important data.
    </div>

    <div class="actions" id="actions">
      <button class="btn-cancel" onclick="respond('no')">Cancel</button>
      <button class="btn-confirm" onclick="respond('yes')">
        Wipe &amp; Create Pool
      </button>
    </div>

    <div class="status" id="status"></div>
    <div class="hostname">frappe.local</div>

    <script>
      const DISKS = __DISK_JSON__;

      function renderDisks() {
        const grid = document.getElementById("diskGrid");
        if (!DISKS.length) {
          grid.innerHTML =
            '<p style="color:var(--muted);text-align:center">No disks detected</p>';
          return;
        }
        grid.innerHTML = DISKS.map(
          (d) => `
    <div class="disk-card">
      <div class="disk-name">
        ${d.model || "Unknown disk"}
        <span class="dev">${d.path}</span>
      </div>
      <div class="disk-meta">
        <span class="label">Size</span>     <span class="value">${d.size}</span>
        <span class="label">Serial</span>   <span class="value">${d.serial || "—"}</span>
        <span class="label">Type</span>     <span class="value">${d.rota ? "HDD (spinning)" : "SSD"}</span>
        <span class="label">Filesystem</span><span class="value">${d.fstype || "none"}</span>
      </div>
    </div>
  `,
        ).join("");
      }

      function respond(choice) {
        document.getElementById("actions").style.display = "none";
        const s = document.getElementById("status");
        s.style.display = "block";
        if (choice === "yes") {
          s.className = "status ok";
          s.textContent = "Confirmed - wiping disks and creating ZFS pool…";
        } else {
          s.className = "status no";
          s.textContent = "Aborted - no changes made.";
        }
        fetch("/disk-confirm/confirm", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ choice }),
        }).catch(() => {});
      }

      renderDisks();
    </script>
  </body>
</html>
"""

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # silence access logs

    def do_GET(self):
        page = HTML.replace("__DISK_JSON__", DISK_JSON)
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(page.encode())

    def do_POST(self):
        if self.path == "/confirm":
            length = int(self.headers.get("Content-Length", 0))
            body   = self.rfile.read(length)
            try:
                data   = json.loads(body)
                choice = data.get("choice", "no")
            except Exception:
                choice = "no"

            with open(SIGNAL_FILE, "w") as f:
                f.write(choice)

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')

            # Shut down server after a short delay so response is sent first
            import threading
            threading.Timer(0.5, self.server.shutdown).start()
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    if os.path.exists(SIGNAL_FILE):
        os.remove(SIGNAL_FILE)
    print(f"[disk-confirm] Serving confirmation UI at http://localhost:{PORT}", flush=True)
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    server.allow_reuse_address = True
    server.serve_forever()
    print(f"[disk-confirm] User responded: {open(SIGNAL_FILE).read().strip()}", flush=True)
