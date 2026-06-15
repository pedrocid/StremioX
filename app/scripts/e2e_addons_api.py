#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import argparse
import json
import sys
import urllib.request


class AddonsAPI(BaseHTTPRequestHandler):
    addons = []

    def do_POST(self):
        if self.path != "/api/addonCollectionGet":
            self.send_json({"error": {"message": "Unknown endpoint"}}, status=404)
            return

        try:
            length = int(self.headers.get("content-length", "0"))
            payload = json.loads(self.rfile.read(length) or b"{}")
        except Exception as exc:
            self.send_json({"error": {"message": f"Bad JSON: {exc}"}}, status=400)
            return

        for manifest_url in payload.get("addFromURL") or []:
            try:
                descriptor = self.fetch_descriptor(manifest_url)
            except Exception as exc:
                self.send_json({"error": {"message": f"Manifest failed: {exc}"}}, status=400)
                return
            self.upsert(descriptor)

        self.send_json({"result": {"addons": self.addons}})

    def log_message(self, fmt, *args):
        sys.stderr.write("[e2e_addons_api] " + fmt % args + "\n")

    @classmethod
    def fetch_descriptor(cls, manifest_url):
        req = urllib.request.Request(
            manifest_url,
            headers={"User-Agent": "StremioX-E2E/1.0"},
        )
        with urllib.request.urlopen(req, timeout=20) as response:
            manifest = json.loads(response.read().decode("utf-8"))
        return {"transportUrl": manifest_url, "manifest": manifest}

    @classmethod
    def upsert(cls, descriptor):
        cls.addons = [
            addon for addon in cls.addons
            if addon.get("transportUrl") != descriptor.get("transportUrl")
        ]
        cls.addons.append(descriptor)

    def send_json(self, payload, status=200):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=18989)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), AddonsAPI)
    print(f"listening http://{args.host}:{args.port}/api", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
