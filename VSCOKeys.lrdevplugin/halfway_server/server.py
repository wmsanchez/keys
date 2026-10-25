#!/usr/bin/env python3
import http.server
import socketserver
import json
import threading

BROADCAST_IP = "127.0.0.1"
PORT = 49657

state_lock = threading.Lock()
currentUUID = ""
clientUpdates = {}
hasUpdates = False
available_presets = []

class HalfwayHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        global currentUUID
        with state_lock:
            if "/Init/" in self.path:
                currentUUID = self.headers.get("UUID", "")
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.send_header("Content-Length", "2")
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(b"OK")
            elif "/Shutdown/" in self.path:
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.send_header("Content-Length", "2")
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(b"OK")
                self.server.shutdown_requested.set()
            elif "/Presets/" in self.path:
                response_body = json.dumps(available_presets).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(response_body)))
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(response_body)
            else:
                self.send_response(404)
                self.send_header("Content-Length", "0")
                self.send_header("Connection", "close")
                self.end_headers()

    def do_POST(self):
        global currentUUID, clientUpdates, hasUpdates, available_presets
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length) if content_length > 0 else b""

        if "/Presets/" in self.path:
            try:
                data = json.loads(post_data.decode('utf-8'))
                if isinstance(data, list):
                    with state_lock:
                        available_presets = [item for item in data if isinstance(item, str)]
            except Exception:
                pass

            response_body = b'{"ok":true}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(response_body)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(response_body)

        elif "/VSCOKeys/" in self.path:
            with state_lock:
                uuid = self.headers.get("UUID", "")
                if uuid:
                    currentUUID = uuid

                resp_body = b""
                if hasUpdates:
                    filtered = {k: v for k, v in clientUpdates.items() if v != 0}
                    if filtered:
                        resp_body = json.dumps(filtered).encode('utf-8')
                    clientUpdates = {}
                    hasUpdates = False

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(resp_body)))
                self.send_header("Connection", "close")
                self.end_headers()
                if resp_body:
                    self.wfile.write(resp_body)

        elif "/Update/" in self.path:
            with state_lock:
                try:
                    data = json.loads(post_data.decode('utf-8'))
                    for k, v in data.items():
                        try:
                            v_num = float(v)
                            clientUpdates[k] = clientUpdates.get(k, 0.0) + v_num
                        except (ValueError, TypeError):
                            clientUpdates[k] = v
                    hasUpdates = True
                except Exception:
                    pass

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", "0")
                self.send_header("Connection", "close")
                self.end_headers()
        else:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.send_header("Connection", "close")
            self.end_headers()

    def log_message(self, format, *args):
        pass

class ReusableTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True

def run():
    try:
        server = ReusableTCPServer((BROADCAST_IP, PORT), HalfwayHandler)
    except Exception:
        return

    server.shutdown_requested = threading.Event()
    server.timeout = 0.5
    while True:
        if server.shutdown_requested.is_set():
            break
        try:
            server.handle_request()
        except Exception:
            pass
    server.server_close()

if __name__ == '__main__':
    run()
