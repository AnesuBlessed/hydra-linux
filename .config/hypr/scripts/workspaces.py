#!/usr/bin/env python3
import sys
import os
import socket
import json
import time

raw_mon = sys.argv[1] if len(sys.argv) > 1 else "global"
# Clean monitor name to match shell sanitization:
mon_name = "".join(c if (c.isalnum() or c in "._-") else "_" for c in raw_mon) or "global"

run_dir = os.environ.get("QS_RUN_WORKSPACES", f"/run/user/{os.getuid()}/quickshell/workspaces")
os.makedirs(run_dir, exist_ok=True)
out_file = os.path.join(run_dir, f"workspaces_{mon_name}.json")
tmp_file = os.path.join(run_dir, f"workspaces_{mon_name}.tmp")

sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
req_sock_path = os.path.join(xdg, "hypr", sig, ".socket.sock")
evt_sock_path = os.path.join(xdg, "hypr", sig, ".socket2.sock")
settings_file = os.path.expanduser("~/.config/hypr/settings.json")

def get_seq_end():
    try:
        with open(settings_file, "r") as f:
            v = int(json.load(f).get("workspaceCount", 8))
            return v if v > 0 else 8
    except Exception:
        return 8

def update_workspaces():
    seq_end = get_seq_end()
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1.0)
        s.connect(req_sock_path)
        s.sendall(b"[[BATCH]]j/workspaces;j/monitors")
        chunks = []
        while True:
            c = s.recv(8192)
            if not c:
                break
            chunks.append(c)
        s.close()
        raw = b"".join(chunks).decode("utf-8", "replace")
        parts = raw.split("\n\n")
        spaces = json.loads(parts[0]) if len(parts) > 0 and parts[0].strip() else []
        monitors = json.loads(parts[1]) if len(parts) > 1 and parts[1].strip() else []
    except Exception:
        return

    active_id = None
    if mon_name == "global":
        for m in monitors:
            if m.get("focused"):
                active_id = m.get("activeWorkspace", {}).get("id")
                break
        if active_id is None and monitors:
            active_id = monitors[0].get("activeWorkspace", {}).get("id")
    else:
        for m in monitors:
            if m.get("name") == mon_name:
                active_id = m.get("activeWorkspace", {}).get("id")
                break
        if active_id is None:
            for m in monitors:
                if m.get("focused"):
                    active_id = m.get("activeWorkspace", {}).get("id")
                    break

    spaces_map = {s["id"]: s for s in spaces if "id" in s}

    res = []
    for i in range(1, seq_end + 1):
        ws_info = spaces_map.get(i)
        win_count = ws_info.get("windows", 0) if ws_info else 0
        state = "active" if i == active_id else ("occupied" if win_count > 0 else "empty")
        tooltip = ws_info.get("lastwindowtitle", "Empty") if ws_info else "Empty"
        res.append({
            "id": i,
            "state": state,
            "tooltip": tooltip
        })

    try:
        with open(tmp_file, "w") as f:
            json.dump(res, f)
        os.replace(tmp_file, out_file)
    except Exception:
        pass

def main():
    # Initial generation
    update_workspaces()

    # Reconnect loop for event socket
    while True:
        try:
            if not os.path.exists(evt_sock_path):
                time.sleep(1)
                continue
            evt_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            evt_sock.connect(evt_sock_path)
            f = evt_sock.makefile("r", encoding="utf-8", errors="replace")
            while True:
                line = f.readline()
                if not line:
                    break
                line = line.strip()
                if line.startswith((
                    "workspace>>", "workspacev2>>", "focusedmon>>",
                    "activewindow>>", "createwindow>>", "closewindow>>",
                    "movewindow>>", "monitoradded>>", "monitorremoved>>"
                )):
                    # Debounce: read any events already waiting in the socket buffer
                    evt_sock.setblocking(False)
                    try:
                        while True:
                            extra = evt_sock.recv(4096)
                            if not extra:
                                break
                    except (BlockingIOError, InterruptedError):
                        pass
                    evt_sock.setblocking(True)
                    f = evt_sock.makefile("r", encoding="utf-8", errors="replace")
                    update_workspaces()
        except Exception:
            time.sleep(1)

if __name__ == "__main__":
    main()
