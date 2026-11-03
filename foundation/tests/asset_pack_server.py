#!/usr/bin/env python3
"""A local file server for tests/asset_pack_test.gd: Range requests (206), a redirect (/go/<name> -> /<name>, as
GitHub sends a release asset on to its storage), and DROP_AFTER bytes: the first full request is cut there (a dropped
connection, so the pack must resume). Logs each request's Range to <dir>/requests.log.
    python3 tests/asset_pack_server.py <dir> <port> [drop_after]
"""
import http.server
import os
import sys

DIR, PORT = sys.argv[1], int(sys.argv[2])
DROP = int(sys.argv[3]) if len(sys.argv) > 3 else 0
state = {"dropped": False}


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        rng = self.headers.get("Range", "")
        with open(os.path.join(DIR, "requests.log"), "a") as log:
            log.write("%s %s\n" % (self.path, rng or "-"))
        if self.path.startswith("/go/"):
            self.send_response(302)
            self.send_header("Location", "/" + self.path[4:])
            self.end_headers()
            return
        f = os.path.join(DIR, self.path.lstrip("/"))
        if not os.path.isfile(f):
            self.send_response(404)
            self.end_headers()
            return
        data = open(f, "rb").read()
        start = 0
        if rng.startswith("bytes="):
            start = int(rng[6:].split("-")[0])
            if start >= len(data):
                self.send_response(416)
                self.end_headers()
                return
            self.send_response(206)
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, len(data) - 1, len(data)))
        else:
            self.send_response(200)
        body = data[start:]
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if DROP and not state["dropped"] and start == 0:
            state["dropped"] = True
            self.wfile.write(body[:DROP])
            self.wfile.flush()
            self.connection.close()
            return
        self.wfile.write(body)


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
