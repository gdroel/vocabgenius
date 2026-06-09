#!/usr/bin/env python3
"""
App Store Server Notifications V2 listener + dashboard.

Apple POSTs subscription lifecycle events (purchases, cancellations,
renewals, expirations, refunds, billing issues, ...) to a URL you
configure in App Store Connect. The body is a single JWS ("signedPayload");
the transaction and renewal details are themselves nested JWS blobs.

This server decodes those payloads (without signature verification — see
the note at the bottom), logs each event, keeps the most recent ones in
memory, and serves a public dashboard with a live feed and a button to
request an Apple TEST notification.

Routes:
    GET  /                -> dashboard (HTML)
    GET  /events          -> recent notifications (JSON), for the dashboard feed
    GET  /healthz         -> "ok" (Render health check)
    POST /notifications   -> Apple delivers signedPayload notifications here
    POST /request-test    -> ask Apple to send a TEST notification (needs creds)

Usage:
    python3 server/appstore_notification_listener.py            # listens on :8080
    PORT=9000 python3 server/appstore_notification_listener.py  # custom port

A single /notifications endpoint receives BOTH sandbox and production events —
point both the Sandbox and Production Server URLs in App Store Connect at it.
Each event is tagged with Apple's own data.environment ("Sandbox"/"Production").

Credentials for the "request test" button (set as env vars / Render secrets):
    ASC_KEY_ID        App Store Connect API key ID
    ASC_ISSUER_ID     App Store Connect issuer ID
    ASC_BUNDLE_ID     app bundle id (e.g. com.vocabgenius.app)
    ASC_PRIVATE_KEY   contents of the .p8 private key (PEM, multi-line)
The test button chooses Sandbox vs Production per request (same key works for both).
"""

import base64
import json
import os
import sys
import threading
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# PyJWT is only needed for the "request test notification" button. Keep the
# import soft so the listener still runs (and logs) even if it's missing.
try:
    import jwt as pyjwt
except ImportError:  # pragma: no cover
    pyjwt = None

PORT = int(os.environ.get("PORT", "8080"))
DASHBOARD_FILE = Path(__file__).with_name("dashboard.html")

# Shared, in-memory ring of recent events — every dashboard viewer sees the
# same feed. Capped so a long-running instance doesn't grow unbounded.
MAX_EVENTS = 200
EVENTS = []
EVENTS_LOCK = threading.Lock()

APPLE_HOSTS = {
    "Sandbox": "https://api.storekit-sandbox.itunes.apple.com",
    "Production": "https://api.storekit.itunes.apple.com",
}

# Icon per notificationType, purely to make the log/feed skimmable.
NOTIF_ICON = {
    "SUBSCRIBED": "🟢",
    "DID_RENEW": "🔄",
    "DID_CHANGE_RENEWAL_STATUS": "🟠",   # subtype tells you cancel vs re-enable
    "DID_CHANGE_RENEWAL_PREF": "🔀",
    "OFFER_REDEEMED": "🎟️",
    "EXPIRED": "⚫",
    "DID_FAIL_TO_RENEW": "⚠️",
    "GRACE_PERIOD_EXPIRED": "⚠️",
    "REFUND": "💸",
    "REFUND_DECLINED": "🚫",
    "PRICE_INCREASE": "📈",
    "RENEWAL_EXTENDED": "⏩",
    "REVOKE": "🔻",
    "CONSUMPTION_REQUEST": "❓",
    "TEST": "🧪",
}

# Plain-English gloss for the cancel/renewal-status case, the one you care about most.
SUBTYPE_NOTE = {
    "AUTO_RENEW_DISABLED": "user turned OFF auto-renew (CANCELLATION — keeps access until expiry)",
    "AUTO_RENEW_ENABLED": "user turned auto-renew back ON (un-cancellation)",
    "INITIAL_BUY": "first-time purchase",
    "RESUBSCRIBE": "resubscribed within the same group",
    "VOLUNTARY": "let subscription lapse voluntarily",
    "BILLING_RETRY": "in billing retry",
    "PRICE_INCREASE": "did not consent to price increase",
    "GRACE_PERIOD": "in grace period",
}


def b64url_json(segment):
    """Decode one base64url JWS segment into a dict."""
    pad = "=" * (-len(segment) % 4)
    return json.loads(base64.urlsafe_b64decode(segment + pad))


def decode_jws_payload(jws):
    """Return the (unverified) payload dict from a compact JWS string."""
    if not isinstance(jws, str) or jws.count(".") != 2:
        return {}
    return b64url_json(jws.split(".")[1])


def ms_to_iso(ms):
    if not ms:
        return None
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).isoformat()


def _price(tx):
    # Apple sends price in milliunits of the currency (e.g. 9990 = 9.99).
    price = tx.get("price")
    currency = tx.get("currency")
    if price is None:
        return None
    return f"{price / 1000:.2f} {currency or ''}".strip()


def summarize(payload):
    """Flatten a decoded notification into a dict used by both the log and feed."""
    ntype = payload.get("notificationType", "UNKNOWN")
    subtype = payload.get("subtype")
    data = payload.get("data", {})
    tx = decode_jws_payload(data.get("signedTransactionInfo", ""))
    renewal = decode_jws_payload(data.get("signedRenewalInfo", ""))
    return {
        "received_at": datetime.now(tz=timezone.utc).isoformat(),
        "icon": NOTIF_ICON.get(ntype, "❓"),
        "type": ntype,
        "subtype": subtype,
        "note": SUBTYPE_NOTE.get(subtype),
        "environment": data.get("environment"),
        "bundleId": data.get("bundleId"),
        "product": tx.get("productId"),
        "txnType": tx.get("type"),
        "transactionId": tx.get("transactionId"),
        "originalTransactionId": tx.get("originalTransactionId"),
        "price": _price(tx),
        "expires": ms_to_iso(tx.get("expiresDate")),
        "autoRenew": renewal.get("autoRenewStatus"),
        "revocation": ms_to_iso(tx.get("revocationDate")),
        "revokeReason": tx.get("revocationReason"),
    }


def store_event(summary):
    with EVENTS_LOCK:
        EVENTS.append(summary)
        del EVENTS[:-MAX_EVENTS]  # keep only the most recent MAX_EVENTS


def log_summary(s):
    header = s["type"] + (f" / {s['subtype']}" if s["subtype"] else "")
    clock = datetime.now().strftime("%H:%M:%S")
    print(f"\n{s['icon']}  [{clock}] {header}")
    if s["note"]:
        print(f"      → {s['note']}")
    for label in ("environment", "bundleId", "product", "txnType", "transactionId",
                  "originalTransactionId", "price", "expires", "autoRenew",
                  "revocation", "revokeReason"):
        value = s.get(label)
        if value not in (None, "", []):
            print(f"      {label:20} {value}")
    sys.stdout.flush()


def request_apple_test_notification(environment="Sandbox"):
    """Ask Apple to send a TEST notification to our configured URL.

    `environment` is "Sandbox" or "Production" — Apple delivers the TEST to the
    correspondingly-configured Server URL. Returns (status_code, result_dict);
    builds a short-lived ES256 JWT from the App Store Connect API key in the env.
    """
    if pyjwt is None:
        return 500, {"error": "PyJWT not installed on the server (pip install -r requirements.txt)."}
    if environment not in APPLE_HOSTS:
        environment = "Sandbox"

    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    bundle_id = os.environ.get("ASC_BUNDLE_ID")
    private_key = os.environ.get("ASC_PRIVATE_KEY")

    missing = [name for name, val in [
        ("ASC_KEY_ID", key_id), ("ASC_ISSUER_ID", issuer_id),
        ("ASC_BUNDLE_ID", bundle_id), ("ASC_PRIVATE_KEY", private_key),
    ] if not val]
    if missing:
        return 400, {"error": f"Missing credentials: {', '.join(missing)}. Set them as env vars on the server."}

    host = APPLE_HOSTS[environment]
    now = int(time.time())
    token = pyjwt.encode(
        {"iss": issuer_id, "iat": now, "exp": now + 600,
         "aud": "appstoreconnect-v1", "bid": bundle_id},
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )

    req = urllib.request.Request(
        f"{host}/inApps/v1/notifications/test",
        data=b"",
        method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read() or b"{}")
            result["environment"] = environment
            print(f"🧪 requested Apple TEST notification ({environment}): {result}")
            sys.stdout.flush()
            return resp.status, result
    except urllib.error.HTTPError as err:
        body = err.read().decode(errors="replace")
        print(f"⚠️  Apple test request failed {err.code}: {body}")
        sys.stdout.flush()
        return err.code, {"error": f"Apple returned {err.code}", "detail": body}
    except urllib.error.URLError as err:
        return 502, {"error": f"Could not reach Apple: {err.reason}"}


class Handler(BaseHTTPRequestHandler):
    def _reply(self, code, body=b"", content_type="text/plain"):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        if self.path == "/" or self.path.startswith("/?"):
            try:
                html = DASHBOARD_FILE.read_bytes()
            except OSError:
                self._reply(500, "dashboard.html not found next to the server script.")
                return
            self._reply(200, html, "text/html; charset=utf-8")
        elif self.path == "/events":
            with EVENTS_LOCK:
                payload = json.dumps(list(reversed(EVENTS))).encode()  # newest first
            self._reply(200, payload, "application/json")
        elif self.path == "/healthz":
            self._reply(200, "ok")
        else:
            self._reply(404, "not found")

    def do_POST(self):
        if self.path.split("?")[0] == "/request-test":
            query = parse_qs(urlparse(self.path).query)
            environment = query.get("env", ["Sandbox"])[0]
            status, result = request_apple_test_notification(environment)
            self._reply(status, json.dumps(result), "application/json")
            return

        if self.path != "/notifications":
            self._reply(404, "not found")
            return

        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b""
        try:
            body = json.loads(raw)
            payload = decode_jws_payload(body["signedPayload"])
        except (json.JSONDecodeError, KeyError, ValueError, TypeError) as err:
            print(f"⚠️  could not parse notification: {err} — body: {raw[:200]!r}")
            self._reply(400, "bad payload")
            return

        summary = summarize(payload)
        store_event(summary)
        log_summary(summary)
        # Return 200 promptly; otherwise Apple retries on a backoff schedule.
        self._reply(200, "ok")

    def log_message(self, *args):
        pass  # silence default per-request access logging


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    creds = "configured" if os.environ.get("ASC_PRIVATE_KEY") else "NOT configured"
    print(f"▶ App Store Notifications V2 listener + dashboard on http://0.0.0.0:{PORT}")
    print(f"  dashboard:     http://localhost:{PORT}/")
    print(f"  notifications: http://localhost:{PORT}/notifications")
    print(f"  test creds:    {creds}")
    print("  Ctrl+C to stop.\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n⏹ stopped.")
        server.shutdown()


if __name__ == "__main__":
    main()

# NOTE on verification: this tool DECODES Apple's JWS but does NOT verify the
# X.509 (x5c) signature chain against Apple's root CA. That's fine for local
# inspection/logging. For anything that grants entitlements, verify the chain
# (e.g. Apple's app-store-server-library for Python/Node/Java/Swift) before
# trusting the contents.
