#!/usr/bin/env python3
import http.client
import json
import threading
import time
import unittest

from server import reset_state, run


POLL_WAIT = 0.4


class LongPollTests(unittest.TestCase):
    def setUp(self):
        reset_state()
        self.ready = {"event": threading.Event(), "port": None, "server": None, "error": False}
        self.thread = threading.Thread(
            target=run,
            kwargs={
                "host": "127.0.0.1",
                "port": 0,
                "poll_wait_seconds": POLL_WAIT,
                "ready": self.ready,
            },
            daemon=True,
        )
        self.thread.start()
        self.assertTrue(self.ready["event"].wait(timeout=2), "server did not start")
        self.assertFalse(self.ready.get("error"), "server failed to bind")
        self.port = self.ready["port"]
        self.server = self.ready["server"]

    def tearDown(self):
        try:
            self._request("GET", "/Shutdown/")
        except Exception:
            pass
        if self.server is not None:
            self.server.shutdown_requested.set()
        self.thread.join(timeout=2)

    def _request(self, method, path, body=None, timeout=5):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=timeout)
        headers = {}
        payload = None
        if body is not None:
            payload = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
            headers["Content-Length"] = str(len(payload))
        try:
            connection.request(method, path, body=payload, headers=headers)
            response = connection.getresponse()
            data = response.read()
            return response.status, data
        finally:
            connection.close()

    def test_idle_poll_returns_204_after_wait(self):
        started = time.monotonic()
        status, body = self._request("POST", "/VSCOKeys/", body={}, timeout=5)
        elapsed = time.monotonic() - started
        self.assertEqual(status, 204)
        self.assertEqual(body, b"")
        self.assertGreaterEqual(elapsed, POLL_WAIT * 0.8)
        self.assertLess(elapsed, POLL_WAIT + 1.5)

    def test_update_unblocks_waiter_with_payload(self):
        result = {}

        def poll():
            result["status"], result["body"] = self._request(
                "POST", "/VSCOKeys/", body={}, timeout=5
            )

        waiter = threading.Thread(target=poll)
        waiter.start()
        time.sleep(0.05)
        update_started = time.monotonic()
        update_status, _ = self._request("POST", "/Update/", body={"Exposure2012": 0.1})
        self.assertEqual(update_status, 200)
        waiter.join(timeout=2)
        self.assertFalse(waiter.is_alive())
        elapsed = time.monotonic() - update_started
        self.assertEqual(result["status"], 200)
        self.assertEqual(json.loads(result["body"].decode("utf-8")), {"Exposure2012": 0.1})
        self.assertLess(elapsed, POLL_WAIT / 2)

    def test_shutdown_unblocks_waiter(self):
        result = {}

        def poll():
            result["status"], result["body"] = self._request(
                "POST", "/VSCOKeys/", body={}, timeout=5
            )

        waiter = threading.Thread(target=poll)
        waiter.start()
        time.sleep(0.05)
        started = time.monotonic()
        self._request("GET", "/Shutdown/")
        waiter.join(timeout=2)
        self.assertFalse(waiter.is_alive())
        elapsed = time.monotonic() - started
        self.assertEqual(result["status"], 204)
        self.assertLess(elapsed, POLL_WAIT / 2)

    def test_empty_update_does_not_wake_as_200(self):
        result = {}

        def poll():
            result["started"] = time.monotonic()
            result["status"], result["body"] = self._request(
                "POST", "/VSCOKeys/", body={}, timeout=5
            )
            result["elapsed"] = time.monotonic() - result["started"]

        waiter = threading.Thread(target=poll)
        waiter.start()
        time.sleep(0.05)
        update_status, _ = self._request("POST", "/Update/", body={})
        self.assertEqual(update_status, 200)
        waiter.join(timeout=2)
        self.assertFalse(waiter.is_alive())
        self.assertEqual(result["status"], 204)
        self.assertEqual(result["body"], b"")
        self.assertGreaterEqual(result["elapsed"], POLL_WAIT * 0.8)


if __name__ == "__main__":
    unittest.main()
