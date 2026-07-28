import requests
import socket
import ssl
import json
import os
import time
from datetime import datetime

# -----------------------------
# Configuration
# -----------------------------
BASE_URL = "https://mithal.space"
SEARCH_URL = "https://mithal.space/search?q=test"

OUTPUT_FILE = "metrics.json"
INTERVAL = 60  # seconds

MAX_RECORDS = 1440  # 24 hours (1 record/min)


# -----------------------------
# HTTP Latency + Uptime
# -----------------------------
def check_http():
    start = time.perf_counter()

    try:
        response = requests.get(BASE_URL, timeout=10)

        latency = round((time.perf_counter() - start) * 1000, 2)

        return {
            "status_code": response.status_code,
            "uptime": response.status_code == 200,
            "latency_ms": latency
        }

    except Exception:
        latency = round((time.perf_counter() - start) * 1000, 2)

        return {
            "status_code": None,
            "uptime": False,
            "latency_ms": latency
        }


# -----------------------------
# DNS Lookup Time
# -----------------------------
def check_dns():
    host = BASE_URL.replace("https://", "").replace("http://", "").split("/")[0]

    start = time.perf_counter()

    try:
        socket.gethostbyname(host)
        dns_time = round((time.perf_counter() - start) * 1000, 2)

    except Exception:
        dns_time = None

    return dns_time


# -----------------------------
# SSL Expiry
# -----------------------------
def check_ssl():
    host = BASE_URL.replace("https://", "").replace("http://", "").split("/")[0]

    try:
        context = ssl.create_default_context()

        with context.wrap_socket(
            socket.socket(socket.AF_INET),
            server_hostname=host
        ) as s:

            s.settimeout(10)
            s.connect((host, 443))

            cert = s.getpeercert()

            expire = datetime.strptime(
                cert["notAfter"],
                "%b %d %H:%M:%S %Y %Z"
            )

            remaining = (expire - datetime.utcnow()).days

            return {
                "expires_at": expire.isoformat(),
                "days_left": remaining
            }

    except Exception:

        return {
            "expires_at": None,
            "days_left": None
        }


# -----------------------------
# Search Response Time
# -----------------------------
def check_search():
    start = time.perf_counter()

    try:
        response = requests.get(
            SEARCH_URL,
            timeout=10
        )

        elapsed = round((time.perf_counter() - start) * 1000, 2)

        return {
            "status": response.status_code,
            "response_ms": elapsed
        }

    except Exception:

        elapsed = round((time.perf_counter() - start) * 1000, 2)

        return {
            "status": None,
            "response_ms": elapsed
        }


# -----------------------------
# Load JSON
# -----------------------------
def load_metrics():

    if not os.path.exists(OUTPUT_FILE):
        return []

    try:
        with open(OUTPUT_FILE, "r") as f:
            return json.load(f)

    except Exception:
        return []


# -----------------------------
# Save JSON
# -----------------------------
def save_metrics(data):

    with open(OUTPUT_FILE, "w") as f:
        json.dump(data, f, indent=4)


# -----------------------------
# Main Monitor Loop
# -----------------------------
def monitor():

    print("Starting Mithal Monitor...")

    while True:

        http = check_http()
        dns = check_dns()
        ssl_info = check_ssl()
        search = check_search()

        record = {
            "timestamp": datetime.utcnow().isoformat(),

            "latency_ms": http["latency_ms"],

            "status_code": http["status_code"],

            "uptime": http["uptime"],

            "dns_lookup_ms": dns,

            "ssl": ssl_info,

            "search": search
        }

        data = load_metrics()

        data.append(record)

        if len(data) > MAX_RECORDS:
            data = data[-MAX_RECORDS:]

        save_metrics(data)

        print(record)

        time.sleep(INTERVAL)


if __name__ == "__main__":
    monitor()