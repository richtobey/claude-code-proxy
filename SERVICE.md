# Running the proxy as a service

Run the Claude Code Proxy as a system service so it starts on boot (or at login on macOS) and restarts on failure.

- **Linux:** systemd
- **macOS:** launchd (user agent, runs at login)

Ensure you have [configured `.env`](README.md#setup-) in the directory you use as `WorkingDirectory` below.

---

## Linux (systemd)

1. **Install the package** (from repo root):

   ```bash
   uv pip install -e .
   # or: pip install .
   ```

   This installs the `claude-code-proxy` console script.

2. **Install the unit file**:

   Copy `deploy/claude-code-proxy.service` to `/etc/systemd/system/`. Edit the unit file: set `WorkingDirectory` and `EnvironmentFile` (and optionally `ExecStart`) to your install path, e.g. `/opt/claude-code-proxy` or your repo path.

   ```bash
   sudo cp deploy/claude-code-proxy.service /etc/systemd/system/
   sudo sed -i 's|/opt/claude-code-proxy|/path/to/your/claude-code-proxy|g' /etc/systemd/system/claude-code-proxy.service
   sudo systemctl daemon-reload
   ```

3. **Enable and start**:

   ```bash
   sudo systemctl enable claude-code-proxy
   sudo systemctl start claude-code-proxy
   sudo systemctl status claude-code-proxy
   ```

**Useful commands:**

- **Logs:** `journalctl -u claude-code-proxy -f`
- **Stop:** `sudo systemctl stop claude-code-proxy`
- **Restart:** `sudo systemctl restart claude-code-proxy`

Host/port can be overridden with `HOST` and `PORT` in `.env` or in the unit file’s `Environment=` lines.

---

## macOS (launchd)

You can run the proxy as a launchd agent so it starts at login and restarts if it exits.

1. **Install the package** (from repo root):

   ```bash
   uv pip install -e .
   # or: pip install .
   ```

   Ensure `.env` is in the same directory you will use as `WorkingDirectory` below.

2. **Install the plist**:

   Copy `deploy/com.claude-code-proxy.plist` to `~/Library/LaunchAgents/`. Edit the plist and replace `/opt/claude-code-proxy` with your install path (the directory that contains `.env` and `.venv`). The first `ProgramArguments` string must be the full path to the executable, e.g. `/Users/you/claude-code-proxy/.venv/bin/claude-code-proxy`; `WorkingDirectory` must be that directory (e.g. `/Users/you/claude-code-proxy`).

   ```bash
   cp deploy/com.claude-code-proxy.plist ~/Library/LaunchAgents/
   # Edit the plist: replace /opt/claude-code-proxy with your path in both ProgramArguments and WorkingDirectory
   # e.g. sed -i '' 's|/opt/claude-code-proxy|/Users/you/claude-code-proxy|g' ~/Library/LaunchAgents/com.claude-code-proxy.plist
   ```

3. **Load and start**:

   ```bash
   launchctl load ~/Library/LaunchAgents/com.claude-code-proxy.plist
   ```

**Useful commands:**

- **Stop:** `launchctl unload ~/Library/LaunchAgents/com.claude-code-proxy.plist`
- **Start again:** `launchctl load ~/Library/LaunchAgents/com.claude-code-proxy.plist`
- **Logs (default):** `tail -f /tmp/claude-code-proxy-stdout.log` and `tail -f /tmp/claude-code-proxy-stderr.log`. You can change `StandardOutPath` / `StandardErrorPath` in the plist to another path.

Host/port can be set with `HOST` and `PORT` in `.env` (the app loads `.env` from `WorkingDirectory`).
