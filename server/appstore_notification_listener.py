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
    ASC_PRIVATE_KEY   contents of the .p8 private key (PEM, multi-line)
    ASC_BUNDLE_ID     optional override; defaults to com.gaberoeloffs.vocabGenius
The test button chooses Sandbox vs Production per request (same key works for both).
"""

import base64
import hmac
import json
import os
import re
import sys
import threading
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import httpx
import psycopg2
import psycopg2.extras

# PyJWT is only needed for the "request test notification" button. Keep the
# import soft so the listener still runs (and logs) even if it's missing.
try:
    import jwt as pyjwt
except ImportError:  # pragma: no cover
    pyjwt = None

PORT = int(os.environ.get("PORT", "8080"))
DASHBOARD_FILE = Path(__file__).with_name("dashboard.html")

# Events persist in Postgres (Render Postgres) so they survive deploys and
# restarts. DATABASE_URL is injected by Render.
MAX_EVENTS = 200  # most-recent notifications shown in the feed
DATABASE_URL = os.environ.get("DATABASE_URL")
DB_LOCK = threading.Lock()
_CONN = None

CLIENT_EVENT_TYPES = {
    "app_opened": {"label": "Opened app", "icon": "📱"},
    "paywall_reached": {"label": "Reached paywall", "icon": "💳"},
    "notification_screen": {"label": "Reached notification screen", "icon": "🔔"},
    "notifications_enabled": {"label": "Enabled notifications", "icon": "✅"},
    "annual_trial_started": {"label": "Started annual trial", "icon": "🎁"},
    "monthly_started": {"label": "Started monthly plan", "icon": "⭐"},
    "lifetime_purchased": {"label": "Bought lifetime", "icon": "💎"},
    # A completed onboarding step. Carries `step` (the screen name) and an
    # optional `value` (what the user picked); both are stored on the event.
    "onboarding_step": {"label": "Onboarding step", "icon": "📝"},
}


def db_exec(query, params=(), fetch=None):
    """Run a query with a lazily-opened, auto-reconnecting connection.

    fetch="all"/"one" returns rows (as dicts); otherwise None. A single
    connection guarded by DB_LOCK is plenty for this low volume, and we
    reconnect once if Postgres dropped the idle connection.
    """
    global _CONN
    with DB_LOCK:
        for attempt in range(2):
            try:
                if _CONN is None or _CONN.closed:
                    _CONN = psycopg2.connect(DATABASE_URL)
                    _CONN.autocommit = True
                with _CONN.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                    cur.execute(query, params)
                    if fetch == "all":
                        return cur.fetchall()
                    if fetch == "one":
                        return cur.fetchone()
                    return None
            except psycopg2.OperationalError:
                _CONN = None  # force reconnect on the retry
                if attempt == 1:
                    raise


def init_db():
    db_exec(
        """CREATE TABLE IF NOT EXISTS notifications(
               id BIGSERIAL PRIMARY KEY,
               received_at TEXT NOT NULL,
               data JSONB NOT NULL)"""
    )
    db_exec(
        """CREATE TABLE IF NOT EXISTS client_events(
               id BIGSERIAL PRIMARY KEY,
               received_at TEXT NOT NULL,
               user_id TEXT NOT NULL,
               event TEXT NOT NULL,
               data JSONB NOT NULL)"""
    )
    db_exec(
        """CREATE TABLE IF NOT EXISTS device_tokens(
               device_token TEXT PRIMARY KEY,
               user_id TEXT NOT NULL,
               updated_at TEXT NOT NULL)"""
    )
    db_exec("CREATE INDEX IF NOT EXISTS idx_client_user ON client_events(user_id)")
    db_exec("CREATE INDEX IF NOT EXISTS idx_device_user ON device_tokens(user_id)")

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

# A free-trial lifecycle is derived from the raw notification, not sent by
# Apple as its own type. Apple delivers a trial START as SUBSCRIBED and a trial
# CANCEL as DID_CHANGE_RENEWAL_STATUS / AUTO_RENEW_DISABLED — identical on the
# surface to a paid purchase or a paid cancellation. The free-trial signal is
# in the transaction's intro-offer fields, so we look there to tell them apart.
TRIAL_LIFECYCLE = {
    "TRIAL_STARTED": {
        "icon": "🎁",
        "note": "FREE TRIAL STARTED (no charge yet — converts to paid at expiry unless cancelled)",
    },
    "TRIAL_CANCELLED": {
        "icon": "🥀",
        "note": "FREE TRIAL CANCELLED (cancelled during the trial — no charge unless they re-enable)",
    },
}


def _is_free_trial(tx):
    """True if this transaction is an introductory FREE-trial period.

    `offerDiscountType` is the authoritative modern field; the offerType==1
    (introductory) + zero-price check is a fallback for older payloads that
    predate offerDiscountType.
    """
    if tx.get("offerDiscountType") == "FREE_TRIAL":
        return True
    return tx.get("offerType") == 1 and tx.get("price") in (0, None)


def trial_lifecycle(ntype, subtype, tx):
    """Classify a notification as a free-trial start/cancel, or None.

    - START : SUBSCRIBED for a transaction that is itself a free trial.
    - CANCEL: auto-renew turned OFF while the CURRENT period is still the
              free trial (a paid-subscription cancel carries a paid current
              transaction, so _is_free_trial filters those out).
    """
    if not _is_free_trial(tx):
        return None
    if ntype == "SUBSCRIBED":
        return "TRIAL_STARTED"
    if ntype == "DID_CHANGE_RENEWAL_STATUS" and subtype == "AUTO_RENEW_DISABLED":
        return "TRIAL_CANCELLED"
    return None


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
    # Derive a free-trial start/cancel and let it override the generic icon/note,
    # since Apple reports both as ordinary subscribe / renewal-status changes.
    lifecycle = trial_lifecycle(ntype, subtype, tx)
    trial = TRIAL_LIFECYCLE.get(lifecycle)
    return {
        "received_at": datetime.now(tz=timezone.utc).isoformat(),
        "icon": trial["icon"] if trial else NOTIF_ICON.get(ntype, "❓"),
        "type": ntype,
        "subtype": subtype,
        "lifecycle": lifecycle,
        "note": trial["note"] if trial else SUBTYPE_NOTE.get(subtype),
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
    db_exec(
        "INSERT INTO notifications(received_at, data) VALUES(%s, %s)",
        (summary["received_at"], psycopg2.extras.Json(summary)),
    )


def recent_notifications():
    rows = db_exec(
        "SELECT data FROM notifications ORDER BY id DESC LIMIT %s",
        (MAX_EVENTS,), fetch="all",
    )
    return [r["data"] for r in rows]  # newest first; jsonb decodes to dict


def store_client_event(user_id, event, environment="unknown", value=None, step=None):
    meta = CLIENT_EVENT_TYPES[event]
    # Build a readable feed label: prefer "Step → selection" for onboarding
    # steps, fall back to "Event: value", else the plain event label.
    if step:
        label = f"{step} → {value}" if value else step
    elif value:
        label = f"{meta['label']}: {value}"
    else:
        label = meta["label"]
    record = {
        "event": event,
        "label": label,
        "icon": meta["icon"],
        # "sandbox" (our Xcode/TestFlight testing) vs "production" (real App
        # Store users) — mirrors Apple's notification environment so the feed
        # and funnels can exclude our own testing. "unknown" for older clients
        # that predate this field.
        "environment": environment,
        "received_at": datetime.now(tz=timezone.utc).isoformat(),
    }
    if value is not None:
        record["value"] = value
    if step is not None:
        record["step"] = step
    db_exec(
        "INSERT INTO client_events(received_at, user_id, event, data) VALUES(%s, %s, %s, %s)",
        (record["received_at"], user_id, event, psycopg2.extras.Json(record)),
    )
    print(f"{meta['icon']}  [client/{environment}] {user_id}: {label}")
    sys.stdout.flush()
    return record


def customers_summary():
    """One row per customer: id, totals, per-event counts, last-seen time."""
    rows = db_exec(
        "SELECT user_id, event, COUNT(*) AS n, MAX(received_at) AS last "
        "FROM client_events GROUP BY user_id, event",
        fetch="all",
    )
    customers = {}
    for r in rows:
        c = customers.setdefault(
            r["user_id"],
            {"userId": r["user_id"], "total": 0, "counts": {}, "lastSeen": None},
        )
        c["counts"][r["event"]] = r["n"]
        c["total"] += r["n"]
        if c["lastSeen"] is None or r["last"] > c["lastSeen"]:
            c["lastSeen"] = r["last"]
    result = list(customers.values())
    result.sort(key=lambda x: x["lastSeen"] or "", reverse=True)
    return result


def customer_timeline(user_id):
    rows = db_exec(
        "SELECT data FROM client_events WHERE user_id=%s ORDER BY id ASC LIMIT 1000",
        (user_id,), fetch="all",
    )
    return [r["data"] for r in rows]  # chronological (oldest first)


# Events that mean the user paid (so they should NOT be re-targeted). The
# monthly/lifetime offers are what the push drives; an annual trial counts as
# "already a customer" too.
PURCHASE_EVENTS = ("monthly_started", "lifetime_purchased", "annual_trial_started")
# The two events the offer push can produce.
OFFER_PURCHASE_EVENTS = ("monthly_started", "lifetime_purchased")


def _offer_from_label(label):
    """Pull the '(monthly)'/'(lifetime)' suffix send_push() stamps on the label."""
    match = re.search(r"\(([^)]*)\)\s*$", label or "")
    return match.group(1) if match else ""


def converted_customers():
    """Customers who were sent an offer push and then completed the offer.

    A conversion counts only when a monthly/lifetime purchase event lands at or
    after one of that customer's notification_sent events — i.e. the push could
    plausibly have driven it. Returns one row per converting customer.
    """
    rows = db_exec(
        "SELECT user_id, event, received_at, data FROM client_events "
        "WHERE event IN ('notification_sent', 'monthly_started', 'lifetime_purchased') "
        "ORDER BY user_id, received_at ASC",
        fetch="all",
    )
    by_user = {}
    for r in rows:
        by_user.setdefault(r["user_id"], []).append(r)
    result = []
    for uid, evs in by_user.items():
        sends = [e for e in evs if e["event"] == "notification_sent"]
        if not sends:
            continue
        conv = matched = None
        for e in evs:
            if e["event"] not in OFFER_PURCHASE_EVENTS:
                continue
            prior = [s for s in sends if s["received_at"] <= e["received_at"]]
            if prior:
                conv, matched = e, prior[-1]
                break  # earliest post-notification conversion
        if not conv:
            continue
        data = conv["data"] or {}
        result.append({
            "userId": uid,
            "environment": data.get("environment") or "unknown",
            "notifiedAt": matched["received_at"],
            "offer": _offer_from_label((matched["data"] or {}).get("label", "")),
            "convertedAt": conv["received_at"],
            "convertedEvent": conv["event"],
            "convertedLabel": data.get("label") or conv["event"],
            "notifyCount": len(sends),
        })
    result.sort(key=lambda x: x["convertedAt"], reverse=True)
    return result


def reengage_customers():
    """Re-engagement targets: reached the paywall, never paid, push-reachable.

    'Push-reachable' means we hold a live APNs device token for them (a token is
    pruned when Apple reports it unregistered), so a 'similar message' can
    actually be delivered. Sorted most-recent-paywall first.
    """
    rows = db_exec(
        "SELECT user_id, event, received_at, data FROM client_events "
        "WHERE event IN ('paywall_reached', 'monthly_started', 'lifetime_purchased', "
        "'annual_trial_started', 'notifications_enabled', 'notification_sent') "
        "ORDER BY user_id, received_at ASC",
        fetch="all",
    )
    token_rows = db_exec("SELECT DISTINCT user_id FROM device_tokens", fetch="all")
    token_users = {r["user_id"] for r in token_rows}
    by_user = {}
    for r in rows:
        by_user.setdefault(r["user_id"], []).append(r)
    result = []
    for uid, evs in by_user.items():
        kinds = {e["event"] for e in evs}
        if "paywall_reached" not in kinds:
            continue
        if kinds & set(PURCHASE_EVENTS):
            continue  # already a customer
        if uid not in token_users:
            continue  # no live token — a push wouldn't land
        paywalls = [e for e in evs if e["event"] == "paywall_reached"]
        last_pw = paywalls[-1]
        result.append({
            "userId": uid,
            "environment": (last_pw["data"] or {}).get("environment") or "unknown",
            "paywallCount": len(paywalls),
            "lastPaywallAt": last_pw["received_at"],
            "notifyCount": sum(1 for e in evs if e["event"] == "notification_sent"),
            "enabledCount": sum(1 for e in evs if e["event"] == "notifications_enabled"),
        })
    result.sort(key=lambda x: x["lastPaywallAt"], reverse=True)
    return result


def trials_summary():
    """One row per free trial (grouped by originalTransactionId).

    Pairs each TRIAL_STARTED with a later TRIAL_CANCELLED on the same
    subscription. Cancelled trials come first, oldest cancellation first;
    still-active trials (started, never cancelled) sit at the bottom, oldest
    start first.
    """
    rows = db_exec(
        "SELECT data FROM notifications "
        "WHERE data->>'lifecycle' IN ('TRIAL_STARTED', 'TRIAL_CANCELLED') "
        "ORDER BY id ASC",
        fetch="all",
    )
    trials = {}
    for r in rows:
        d = r["data"] or {}
        # Fall back to transactionId if Apple omitted the original id.
        key = d.get("originalTransactionId") or d.get("transactionId") or d.get("received_at")
        t = trials.setdefault(key, {
            "originalTransactionId": key,
            "environment": d.get("environment") or "unknown",
            "product": d.get("product"),
            "startedAt": None,
            "cancelledAt": None,
            "expires": None,
        })
        when = d.get("received_at")
        if d.get("lifecycle") == "TRIAL_STARTED":
            if t["startedAt"] is None or (when and when < t["startedAt"]):
                t["startedAt"] = when
        else:  # TRIAL_CANCELLED — keep the latest cancellation
            if t["cancelledAt"] is None or (when and when > t["cancelledAt"]):
                t["cancelledAt"] = when
        if d.get("product"):
            t["product"] = d.get("product")
        if d.get("expires"):
            t["expires"] = d.get("expires")
    result = list(trials.values())
    for t in result:
        t["status"] = "cancelled" if t["cancelledAt"] else "active"
    # Cancelled (rank 0) before active (rank 1); within each, oldest first by the
    # relevant timestamp (cancellation time for cancelled, start time for active).
    result.sort(key=lambda t: (
        0 if t["status"] == "cancelled" else 1,
        (t["cancelledAt"] if t["status"] == "cancelled" else t["startedAt"]) or "",
    ))
    return result


# ---- Push notifications (APNs) -------------------------------------------

APNS_HOSTS = {
    "sandbox": "api.sandbox.push.apple.com",
    "production": "api.push.apple.com",
}
# Reasons that mean "right token, wrong APNs environment" — retry the other host.
APNS_WRONG_ENV = {"BadDeviceToken", "BadEnvironmentKeyInToken"}


def store_device_token(user_id, token):
    db_exec(
        "INSERT INTO device_tokens(device_token, user_id, updated_at) VALUES(%s, %s, %s) "
        "ON CONFLICT(device_token) DO UPDATE SET user_id=EXCLUDED.user_id, updated_at=EXCLUDED.updated_at",
        (token, user_id, datetime.now(tz=timezone.utc).isoformat()),
    )


def tokens_for_user(user_id):
    rows = db_exec(
        "SELECT device_token FROM device_tokens WHERE user_id=%s", (user_id,), fetch="all"
    )
    return [r["device_token"] for r in rows]


def send_push(user_id, title, body, route="monthly"):
    """Send an alert push to every device registered for this customer.

    The payload carries a `route` ("monthly" or "lifetime") that tells the app
    which offer paywall to open on tap; the app treats any unknown value as the
    monthly offer. Tries the configured APNs environment first and falls back to
    the other host on an environment-mismatch token error.
    """
    tokens = tokens_for_user(user_id)
    if not tokens:
        return 404, {"error": "No registered devices for this customer yet."}

    team_id = (os.environ.get("APNS_TEAM_ID") or "").strip()
    key_id = (os.environ.get("APNS_KEY_ID") or "").strip()
    private_key = (os.environ.get("APNS_PRIVATE_KEY") or "").strip()
    bundle_id = (os.environ.get("APNS_BUNDLE_ID") or "com.gaberoeloffs.vocabGenius").strip()
    default_env = (os.environ.get("APNS_ENVIRONMENT") or "sandbox").strip().lower()

    missing = [n for n, v in [("APNS_TEAM_ID", team_id), ("APNS_KEY_ID", key_id),
                              ("APNS_PRIVATE_KEY", private_key)] if not v]
    if missing:
        return 400, {"error": f"Missing APNs credentials: {', '.join(missing)}. Set them as env vars."}
    if pyjwt is None:
        return 500, {"error": "PyJWT not installed on the server."}

    try:
        provider_token = pyjwt.encode(
            {"iss": team_id, "iat": int(time.time())},
            private_key, algorithm="ES256", headers={"kid": key_id},
        )
    except Exception as err:
        return 400, {"error": "Could not sign the APNs token — check APNS_PRIVATE_KEY (.p8 PEM).",
                     "detail": f"{type(err).__name__}: {err}"}

    alert = {}
    if title:
        alert["title"] = title
    if body:
        alert["body"] = body
    payload = {"aps": {"alert": alert, "sound": "default"}, "route": route}
    headers = {"authorization": f"bearer {provider_token}", "apns-topic": bundle_id,
               "apns-push-type": "alert", "apns-priority": "10"}
    host_order = (["sandbox", "production"] if default_env == "sandbox"
                  else ["production", "sandbox"])

    results = []
    try:
        with httpx.Client(http2=True, timeout=20) as client:
            for tok in tokens:
                outcome = None
                for env in host_order:
                    resp = client.post(f"https://{APNS_HOSTS[env]}/3/device/{tok}",
                                       json=payload, headers=headers)
                    if resp.status_code == 200:
                        outcome = {"token": tok[:8] + "…", "ok": True, "environment": env}
                        break
                    try:
                        reason = resp.json().get("reason", "")
                    except Exception:
                        reason = resp.text[:120]
                    if reason in APNS_WRONG_ENV and env != host_order[-1]:
                        continue  # token belongs to the other environment — retry
                    if reason in ("Unregistered", "BadDeviceToken"):
                        db_exec("DELETE FROM device_tokens WHERE device_token=%s", (tok,))
                    outcome = {"token": tok[:8] + "…", "ok": False,
                               "status": resp.status_code, "reason": reason}
                    break
                results.append(outcome)
    except Exception as err:
        return 502, {"error": f"APNs request failed: {type(err).__name__}: {err}"}

    sent = sum(1 for r in results if r and r.get("ok"))
    print(f"📤 push to {user_id}: {sent}/{len(tokens)} delivered — {results}")
    sys.stdout.flush()

    # Record the send (with its copy + which offer) on the customer's timeline.
    if sent:
        offer = "lifetime" if route == "lifetime" else "monthly"
        text = " — ".join(p for p in [title, body] if p)
        suffix = f" ({offer})"
        record = {
            "event": "notification_sent",
            "label": (f"Sent: {text}{suffix}" if text
                      else f"Notification sent{suffix}"),
            "icon": "📤",
            "received_at": datetime.now(tz=timezone.utc).isoformat(),
        }
        db_exec(
            "INSERT INTO client_events(received_at, user_id, event, data) VALUES(%s, %s, %s, %s)",
            (record["received_at"], user_id, "notification_sent",
             psycopg2.extras.Json(record)),
        )

    return (200 if sent else 502), {"sent": sent, "total": len(tokens), "results": results}


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

    # .strip() guards against the #1 cause of Apple 401s: a stray newline or
    # space pasted into the Render env var for the Key ID / Issuer ID.
    key_id = (os.environ.get("ASC_KEY_ID") or "").strip()
    issuer_id = (os.environ.get("ASC_ISSUER_ID") or "").strip()
    # Bundle id is hardcoded (env var optional, only to override).
    bundle_id = (os.environ.get("ASC_BUNDLE_ID") or "com.gaberoeloffs.vocabGenius").strip()
    private_key = (os.environ.get("ASC_PRIVATE_KEY") or "").strip()

    missing = [name for name, val in [
        ("ASC_KEY_ID", key_id), ("ASC_ISSUER_ID", issuer_id),
        ("ASC_PRIVATE_KEY", private_key),
    ] if not val]
    if missing:
        return 400, {"error": f"Missing credentials: {', '.join(missing)}. Set them as env vars on the server."}

    # Identifiers (not secrets) — echoed back on failure so you can cross-check
    # them against App Store Connect. The .p8 contents are never returned.
    using = {"key_id": key_id, "issuer_id": issuer_id, "bundle_id": bundle_id,
             "environment": environment}

    host = APPLE_HOSTS[environment]
    now = int(time.time())
    try:
        token = pyjwt.encode(
            {"iss": issuer_id, "iat": now, "exp": now + 600,
             "aud": "appstoreconnect-v1", "bid": bundle_id},
            private_key,
            algorithm="ES256",
            headers={"kid": key_id, "typ": "JWT"},
        )
    except Exception as err:  # malformed .p8, wrong key type, etc.
        return 400, {"error": "Could not sign the token — check ASC_PRIVATE_KEY is the full .p8 PEM.",
                     "detail": f"{type(err).__name__}: {err}", "using": using}

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
        print(f"⚠️  Apple test request failed {err.code} (using {using}): {body}")
        sys.stdout.flush()
        hint = ""
        if err.code == 401:
            hint = ("401 = Apple rejected the token's identity. Verify ASC_KEY_ID and "
                    "ASC_ISSUER_ID exactly match the key in App Store Connect, and that "
                    "ASC_PRIVATE_KEY is that same key's .p8.")
        return err.code, {"error": f"Apple returned {err.code}", "detail": body,
                          "hint": hint, "using": using}
    except urllib.error.URLError as err:
        return 502, {"error": f"Could not reach Apple: {err.reason}"}


# A single shared password gates the browser dashboard (the HTML page and its
# data/action endpoints). Machine endpoints — Apple's webhook, the app's client
# events / device registration, and the health check — are intentionally left
# open so they never see a 401.
DASHBOARD_PASSWORD = "Iloveb3ar!"


def password_ok(auth_header):
    """True if an HTTP Basic `Authorization` header carries the dashboard
    password. The username is ignored — only the password must match — and the
    comparison is constant-time to avoid leaking it via timing."""
    if not auth_header or not auth_header.startswith("Basic "):
        return False
    try:
        decoded = base64.b64decode(auth_header[6:]).decode("utf-8", "replace")
    except (ValueError, UnicodeError):
        return False
    _user, _sep, password = decoded.partition(":")
    return hmac.compare_digest(password, DASHBOARD_PASSWORD)


class Handler(BaseHTTPRequestHandler):
    def _authed(self):
        """Gate a browser-facing route behind the shared password.

        Returns True when the request carries valid Basic-Auth credentials.
        Otherwise sends a 401 that triggers the browser's native login prompt
        and returns False — the caller should then just return.
        """
        if password_ok(self.headers.get("Authorization")):
            return True
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Professor Pip dashboard"')
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", "0")
        self.end_headers()
        return False

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
        # Health check stays public for Render; everything else a browser hits
        # (the dashboard page and its feeds) requires the shared password.
        if self.path == "/healthz":
            self._reply(200, "ok")
            return
        if not self._authed():
            return
        if self.path == "/" or self.path.startswith("/?"):
            try:
                html = DASHBOARD_FILE.read_bytes()
            except OSError:
                self._reply(500, "dashboard.html not found next to the server script.")
                return
            self._reply(200, html, "text/html; charset=utf-8")
        elif self.path == "/events":
            self._reply(200, json.dumps(recent_notifications()), "application/json")
        elif self.path == "/customers":
            self._reply(200, json.dumps(customers_summary()), "application/json")
        elif self.path == "/converted":
            self._reply(200, json.dumps(converted_customers()), "application/json")
        elif self.path == "/reengage":
            self._reply(200, json.dumps(reengage_customers()), "application/json")
        elif self.path == "/trials":
            self._reply(200, json.dumps(trials_summary()), "application/json")
        elif self.path.split("?")[0] == "/customer":
            user_id = parse_qs(urlparse(self.path).query).get("id", [""])[0]
            self._reply(200, json.dumps(customer_timeline(user_id)), "application/json")
        else:
            self._reply(404, "not found")

    def do_POST(self):
        if self.path.split("?")[0] == "/request-test":
            if not self._authed():
                return
            query = parse_qs(urlparse(self.path).query)
            environment = query.get("env", ["Sandbox"])[0]
            status, result = request_apple_test_notification(environment)
            self._reply(status, json.dumps(result), "application/json")
            return

        if self.path == "/register-device":
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b""
            try:
                body = json.loads(raw)
                token = (body["deviceToken"] or "").strip()
            except (json.JSONDecodeError, KeyError, TypeError, AttributeError):
                self._reply(400, "bad device registration")
                return
            if not token:
                self._reply(400, json.dumps({"error": "deviceToken required"}), "application/json")
                return
            user_id = (body.get("userId") or "anonymous").strip() or "anonymous"
            store_device_token(user_id, token)
            print(f"📲 [client] registered device for {user_id}: {token[:8]}…")
            sys.stdout.flush()
            self._reply(200, "ok")
            return

        if self.path == "/send-push":
            if not self._authed():
                return
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b""
            try:
                body = json.loads(raw)
            except (json.JSONDecodeError, TypeError):
                self._reply(400, "bad send-push request")
                return
            user_id = (body.get("userId") or "").strip()
            title = (body.get("title") or "").strip()
            text = (body.get("body") or "").strip()
            route = "lifetime" if (body.get("route") == "lifetime") else "monthly"
            if not user_id or not (title or text):
                self._reply(400, json.dumps({"error": "userId and a title or body are required"}),
                            "application/json")
                return
            status, result = send_push(user_id, title, text, route=route)
            self._reply(status, json.dumps(result), "application/json")
            return

        if self.path == "/client-event":
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b""
            try:
                body = json.loads(raw)
                event = body["event"]
            except (json.JSONDecodeError, KeyError, TypeError):
                self._reply(400, "bad client event")
                return
            if event not in CLIENT_EVENT_TYPES:
                self._reply(400, json.dumps({"error": f"unknown event '{event}'"}), "application/json")
                return
            user_id = (body.get("userId") or "anonymous").strip() or "anonymous"
            environment = (body.get("environment") or "unknown").strip() or "unknown"
            value = body.get("value")
            step = body.get("step")
            store_client_event(user_id, event, environment, value=value, step=step)
            self._reply(200, "ok")
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
    if not DATABASE_URL:
        sys.exit("DATABASE_URL is not set — create a Render Postgres and link it.")
    init_db()
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
