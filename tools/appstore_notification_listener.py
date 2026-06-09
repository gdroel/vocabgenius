#!/usr/bin/env python3
"""
Local App Store Server Notifications V2 listener.

Apple POSTs subscription lifecycle events (purchases, cancellations,
renewals, expirations, refunds, billing issues, ...) to a URL you
configure in App Store Connect. The body is a single JWS ("signedPayload");
the transaction and renewal details are themselves nested JWS blobs.

This server decodes those payloads (without signature verification — see
the note at the bottom) and logs each event as it arrives.

Usage:
    python3 tools/appstore_notification_listener.py            # listens on :8080
    PORT=9000 python3 tools/appstore_notification_listener.py  # custom port

Then expose it to Apple with ngrok and paste the public URL (+ /notifications)
into App Store Connect:
    ngrok http 8080
    App Store Connect -> your app -> General -> App Information
        -> App Store Server Notifications
        Production / Sandbox URL: https://<subdomain>.ngrok-free.app/notifications
    (Use the "Sandbox" URL field while testing with a sandbox account, or hit
     "Request a Test Notification" from the App Store Server API to fire a TEST.)
"""

import base64
import json
import os
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("PORT", "8080"))

# Icon per notificationType, purely to make the log skimmable.
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


def log_notification(payload):
    ntype = payload.get("notificationType", "UNKNOWN")
    subtype = payload.get("subtype")
    icon = NOTIF_ICON.get(ntype, "❓")
    now = datetime.now().strftime("%H:%M:%S")

    data = payload.get("data", {})
    tx = decode_jws_payload(data.get("signedTransactionInfo", ""))
    renewal = decode_jws_payload(data.get("signedRenewalInfo", ""))

    header = f"{ntype}" + (f" / {subtype}" if subtype else "")
    print(f"\n{icon}  [{now}] {header}")

    note = SUBTYPE_NOTE.get(subtype)
    if note:
        print(f"      → {note}")

    fields = [
        ("environment", data.get("environment")),
        ("bundleId", data.get("bundleId")),
        ("product", tx.get("productId")),
        ("type", tx.get("type")),
        ("transactionId", tx.get("transactionId")),
        ("origTxnId", tx.get("originalTransactionId")),
        ("price", _price(tx)),
        ("expires", ms_to_iso(tx.get("expiresDate"))),
        ("auto_renew", renewal.get("autoRenewStatus")),
        ("revocation", ms_to_iso(tx.get("revocationDate"))),
        ("revoke_reason", tx.get("revocationReason")),
    ]
    for label, value in fields:
        if value not in (None, "", []):
            print(f"      {label:14} {value}")
    sys.stdout.flush()


def _price(tx):
    # Apple sends price in milliunits of the currency (e.g. 9990 = 9.99).
    price = tx.get("price")
    currency = tx.get("currency")
    if price is None:
        return None
    return f"{price / 1000:.2f} {currency or ''}".strip()


class Handler(BaseHTTPRequestHandler):
    def _reply(self, code, body=""):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        if body:
            self.wfile.write(body.encode())

    def do_GET(self):
        # Health check so you can confirm the tunnel is live in a browser.
        self._reply(200, "appstore notification listener alive\n")

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b""
        try:
            body = json.loads(raw)
            payload = decode_jws_payload(body["signedPayload"])
        except (json.JSONDecodeError, KeyError, ValueError, TypeError) as err:
            print(f"⚠️  could not parse notification: {err} — body: {raw[:200]!r}")
            self._reply(400, "bad payload")
            return

        log_notification(payload)
        # Return 200 promptly; otherwise Apple retries on a backoff schedule.
        self._reply(200, "ok")

    def log_message(self, *args):
        pass  # silence default per-request access logging


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"▶ App Store Server Notifications V2 listener on http://0.0.0.0:{PORT}")
    print(f"  POST notifications to  http://localhost:{PORT}/notifications")
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
