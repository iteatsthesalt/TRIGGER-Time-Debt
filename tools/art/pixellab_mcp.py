#!/usr/bin/env python3
"""A tiny client for PixelLab's MCP server (streamable HTTP, JSON-RPC), for listings, job polling and the
occasional generation when Nich asks. The token comes from PIXELLAB_TOKEN, else from the local Claude config
(`claude mcp add pixellab https://api.pixellab.ai/mcp -t http -H "Authorization: Bearer ..."`); it is never
printed. Downloads of finished characters/objects need no token at all (see pixellab_import.py).

    python3 tools/art/pixellab_mcp.py list_characters '{"limit": 50}'
    python3 tools/art/pixellab_mcp.py get_character '{"character_id": "<uuid>"}'
    python3 tools/art/pixellab_mcp.py get_balance
    python3 tools/art/pixellab_mcp.py --tools            # every tool name the server offers
"""
import json
import os
import ssl
import sys
import urllib.request

URL = "https://api.pixellab.ai/mcp"
CA = "/root/.ccr/ca-bundle.crt"


def _token():
    tok = os.environ.get("PIXELLAB_TOKEN", "")
    if tok:
        return tok if tok.lower().startswith("bearer ") else "Bearer " + tok
    cfg = os.path.expanduser("~/.claude.json")
    if os.path.exists(cfg):
        with open(cfg) as f:
            data = json.load(f)
        for proj in data.get("projects", {}).values():
            srv = proj.get("mcpServers", {}).get("pixellab")
            if srv and srv.get("headers", {}).get("Authorization"):
                return srv["headers"]["Authorization"]
        srv = data.get("mcpServers", {}).get("pixellab")
        if srv and srv.get("headers", {}).get("Authorization"):
            return srv["headers"]["Authorization"]
    raise SystemExit("no PixelLab token: set PIXELLAB_TOKEN or `claude mcp add pixellab ...`")


class PixelLab:
    def __init__(self):
        self.auth = _token()
        self.ctx = ssl.create_default_context(cafile=CA) if os.path.exists(CA) else ssl.create_default_context()
        self.sid = None
        self.n = 0
        self._rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                 "clientInfo": {"name": "trigger-time-debt", "version": "1"}})
        self._rpc("notifications/initialized", {}, notify=True)

    def _rpc(self, method, params=None, notify=False):
        self.n += 1
        body = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            body["params"] = params
        if not notify:
            body["id"] = self.n
        headers = {"Authorization": self.auth, "Content-Type": "application/json",
                   "Accept": "application/json, text/event-stream"}
        if self.sid:
            headers["Mcp-Session-Id"] = self.sid
        req = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST", headers=headers)
        with urllib.request.urlopen(req, timeout=180, context=self.ctx) as r:
            if r.headers.get("Mcp-Session-Id"):
                self.sid = r.headers["Mcp-Session-Id"]
            raw = r.read().decode("utf-8", "replace")
            ctype = r.headers.get("Content-Type", "")
        if notify:
            return None
        if "text/event-stream" in ctype:
            msgs = [json.loads(l[5:].strip()) for l in raw.splitlines() if l.startswith("data:")]
            for m in msgs:
                if m.get("id") == self.n:
                    return m
            return msgs[-1] if msgs else None
        return json.loads(raw) if raw.strip() else None

    def tools(self):
        return [t["name"] for t in self._rpc("tools/list", {})["result"]["tools"]]

    def call(self, tool, args=None):
        """-> the tool's text result (prefixed with ERROR: when the server reports one)."""
        res = self._rpc("tools/call", {"name": tool, "arguments": args or {}})
        if res is None:
            return ""
        if "error" in res:
            return "ERROR: " + json.dumps(res["error"])
        r = res.get("result", {})
        text = "\n".join(c.get("text", "") for c in r.get("content", []) if c.get("type") == "text")
        return ("ERROR: " + text) if r.get("isError") else text


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    pl = PixelLab()
    if sys.argv[1] == "--tools":
        print("\n".join(sorted(pl.tools())))
        return
    args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    print(pl.call(sys.argv[1], args))


if __name__ == "__main__":
    main()
