#!/usr/bin/env python3
import http.server
import json
import socketserver
import threading
import time

BROADCAST_IP = "127.0.0.1"
PORT = 49657
POLL_WAIT_SECONDS = 25.0

state_lock = threading.Lock()
updates_cv = threading.Condition(state_lock)
currentUUID = ""
clientUpdates = {}
hasUpdates = False
available_presets = []
plugin_settings = {
    "denoiseAmount": 50,
    "hiddenActions": {},
    "brushIncreaseKey": "]",
    "brushDecreaseKey": "[",
}


def reset_state():
    global currentUUID, clientUpdates, hasUpdates, available_presets, plugin_settings
    with state_lock:
        currentUUID = ""
        clientUpdates = {}
        hasUpdates = False
        available_presets = []
        plugin_settings = {
            "denoiseAmount": 50,
            "hiddenActions": {},
            "brushIncreaseKey": "]",
            "brushDecreaseKey": "[",
        }


def _merge_update(data):
    global clientUpdates, hasUpdates
    changed = False
    if not isinstance(data, dict) or not data:
        return False
    for key, value in data.items():
        try:
            value_num = float(value)
            clientUpdates[key] = clientUpdates.get(key, 0.0) + value_num
        except (ValueError, TypeError):
            clientUpdates[key] = value
        changed = True
    if changed:
        hasUpdates = True
        updates_cv.notify_all()
    return changed


def _drain_updates():
    global clientUpdates, hasUpdates
    filtered = {key: value for key, value in clientUpdates.items() if value != 0}
    clientUpdates = {}
    hasUpdates = False
    return filtered


def _shutdown_requested(handler):
    event = getattr(handler.server, "shutdown_requested", None)
    return event is not None and event.is_set()


class HalfwayHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, status, body=b"", content_type="text/plain"):
        self.send_response(status)
        if body:
            self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        global currentUUID
        if "/Init/" in self.path:
            with state_lock:
                currentUUID = self.headers.get("UUID", "")
            self._send(200, b"OK")
        elif "/Shutdown/" in self.path:
            self._send(200, b"OK")
            shutdown_event = getattr(self.server, "shutdown_requested", None)
            if shutdown_event is not None:
                shutdown_event.set()
            with updates_cv:
                updates_cv.notify_all()
        elif "/Presets/" in self.path:
            with state_lock:
                response_body = json.dumps(available_presets).encode("utf-8")
            self._send(200, response_body, "application/json")
        elif "/Settings/" in self.path:
            with state_lock:
                response_body = json.dumps(plugin_settings).encode("utf-8")
            self._send(200, response_body, "application/json")
        else:
            self._send(404)

    def do_POST(self):
        global currentUUID, available_presets, plugin_settings
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length) if content_length > 0 else b""

        if "/Presets/" in self.path:
            try:
                data = json.loads(post_data.decode("utf-8"))
                if isinstance(data, list):
                    with state_lock:
                        available_presets = [item for item in data if isinstance(item, str)]
            except Exception:
                pass
            self._send(200, b'{"ok":true}', "application/json")

        elif "/Settings/" in self.path:
            try:
                data = json.loads(post_data.decode("utf-8"))
                if isinstance(data, dict):
                    try:
                        denoise_amount = int(data.get("denoiseAmount", 50))
                    except (TypeError, ValueError):
                        denoise_amount = 50
                    hidden_actions = data.get("hiddenActions", {})
                    if not isinstance(hidden_actions, dict):
                        hidden_actions = {}
                    brush_increase_key = data.get("brushIncreaseKey", "]")
                    if not isinstance(brush_increase_key, str) or len(brush_increase_key) != 1:
                        brush_increase_key = "]"
                    brush_decrease_key = data.get("brushDecreaseKey", "[")
                    if not isinstance(brush_decrease_key, str) or len(brush_decrease_key) != 1:
                        brush_decrease_key = "["
                    with state_lock:
                        plugin_settings = {
                            "denoiseAmount": max(1, min(100, denoise_amount)),
                            "hiddenActions": {
                                str(action_id): True
                                for action_id, hidden in hidden_actions.items()
                                if hidden is True
                            },
                            "brushIncreaseKey": brush_increase_key,
                            "brushDecreaseKey": brush_decrease_key,
                        }
            except (UnicodeDecodeError, json.JSONDecodeError):
                pass
            self._send(200, b'{"ok":true}', "application/json")

        elif "/VSCOKeys/" in self.path:
            poll_wait = getattr(self.server, "poll_wait_seconds", POLL_WAIT_SECONDS)
            filtered = {}
            with updates_cv:
                uuid = self.headers.get("UUID", "")
                if uuid:
                    currentUUID = uuid

                deadline = time.monotonic() + float(poll_wait)
                while not hasUpdates and not _shutdown_requested(self):
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        break
                    updates_cv.wait(timeout=remaining)

                if hasUpdates:
                    filtered = _drain_updates()

            if filtered:
                body = json.dumps(filtered).encode("utf-8")
                self._send(200, body, "application/json")
            else:
                self._send(204)

        elif "/Update/" in self.path:
            try:
                data = json.loads(post_data.decode("utf-8"))
            except Exception:
                data = None
            with updates_cv:
                _merge_update(data)
            self._send(200, b"", "application/json")
        else:
            self._send(404)

    def log_message(self, format, *args):
        pass


class ReusableTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


def run(host=BROADCAST_IP, port=PORT, poll_wait_seconds=POLL_WAIT_SECONDS, ready=None):
    try:
        server = ReusableTCPServer((host, port), HalfwayHandler)
    except Exception:
        if ready is not None:
            ready["error"] = True
            ready["event"].set()
        return None

    server.shutdown_requested = threading.Event()
    server.poll_wait_seconds = poll_wait_seconds
    server.timeout = 0.5

    if ready is not None:
        ready["port"] = server.server_address[1]
        ready["server"] = server
        ready["event"].set()

    try:
        while not server.shutdown_requested.is_set():
            try:
                server.handle_request()
            except Exception:
                pass
    finally:
        with updates_cv:
            updates_cv.notify_all()
        server.server_close()
    return server


if __name__ == "__main__":
    run()
