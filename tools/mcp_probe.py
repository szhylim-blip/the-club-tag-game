#!/usr/bin/env python3
"""Talk to the project's godot-mcp server over real MCP stdio JSON-RPC.

    python tools/mcp_probe.py --list
    python tools/mcp_probe.py --call godot_status
    python tools/mcp_probe.py --call godot_run_start '{"mode":"process","args":["--hub"]}'

Prints each raw JSON-RPC response (truncated) so a call can be shown as proof.
"""

import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG = "@shin2344234/godot-mcp@0.1.2"


def main() -> int:
    args = sys.argv[1:]
    mode = "list"
    tool = None
    payload = {}
    if not args:
        pass
    elif args[0] == "--list":
        mode = "list"
    elif args[0] == "--schema" and len(args) >= 2:
        mode = "schema"
        tool = args[1]
    elif args[0] == "--call" and len(args) >= 2:
        mode = "call"
        tool = args[1]
        if len(args) >= 3:
            payload = json.loads(args[2])
    else:
        print(__doc__)
        return 2

    npx = shutil.which("npx") or shutil.which("npx.cmd") or "npx"
    cmd = [npx, "-y", PKG, "--project", ROOT]
    print("spawn:", " ".join(cmd))
    proc = subprocess.Popen(
        cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, bufsize=1, cwd=ROOT,
    )
    inbox: "queue.Queue[dict]" = queue.Queue()

    def pump_out():
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            if line.startswith("{"):
                try:
                    inbox.put(json.loads(line))
                except json.JSONDecodeError:
                    print("RAW:", line[:300])
            else:
                print("LOG:", line[:300])

    def pump_err():
        for line in proc.stderr:
            line = line.strip()
            if line:
                print("ERR:", line[:300])

    threading.Thread(target=pump_out, daemon=True).start()
    threading.Thread(target=pump_err, daemon=True).start()

    def send(obj):
        proc.stdin.write(json.dumps(obj) + "\n")
        proc.stdin.flush()

    def wait(msg_id, timeout=180):
        end = time.time() + timeout
        while time.time() < end:
            try:
                msg = inbox.get(timeout=1.0)
            except queue.Empty:
                continue
            if msg.get("id") == msg_id:
                return msg
            if "method" in msg and "id" in msg:
                # server-initiated request: answer minimally so it does not stall
                send({"jsonrpc": "2.0", "id": msg["id"], "result": {}})
        return None

    try:
        send({
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "club-verifier", "version": "1.0"},
            },
        })
        init = wait(1, 120)
        if init is None:
            print("NO INITIALIZE RESPONSE")
            return 1
        server = init.get("result", {}).get("serverInfo", {})
        print("INIT", json.dumps(server))

        send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        send({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        listing = wait(2, 120)
        if listing is None:
            print("NO TOOLS RESPONSE")
            return 1
        tools = listing.get("result", {}).get("tools", [])
        print("TOOLS", len(tools))
        for t in tools:
            print("  -", t.get("name"))

        if mode == "schema":
            for t in tools:
                if t.get("name") == tool:
                    print("SCHEMA", json.dumps(t, indent=1)[:6000])
                    return 0
            print("unknown tool:", tool)
            return 2

        if mode == "call":
            if tool not in {t.get("name") for t in tools}:
                print("unknown tool:", tool)
                return 2
            send({
                "jsonrpc": "2.0", "id": 3, "method": "tools/call",
                "params": {"name": tool, "arguments": payload},
            })
            res = wait(3, 300)
            if res is None:
                print("NO TOOL RESPONSE")
                return 1
            print("TOOL_RESULT", json.dumps(res)[:4000])
            return 0 if "error" not in res else 1
        return 0
    finally:
        try:
            proc.stdin.close()
        except Exception:
            pass
        time.sleep(0.2)
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    sys.exit(main())
