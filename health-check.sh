#!/bin/bash

# Configuration
API_URL="${API_URL:-https://ghaymah-task-da46b224b9fc.hosted.ghaymah.systems}"
CHECK_INTERVAL=30
STATUS_FILE="status.json"

echo "=================================================="
echo "   Starting Ghaymah SRE Monitoring Agent          "
echo "   Target URL : $API_URL                          "
echo "   Interval   : ${CHECK_INTERVAL}s                 "
echo "=================================================="

while true; do
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    START_TIME=$(date +%s%N)
    HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" "${API_URL}/metrics")
    END_TIME=$(date +%s%N)

    # Calculate latency in milliseconds
    LATENCY_MS=$(( (END_TIME - START_TIME) / 1000000 ))

    HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
    HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)

    if [ "$HTTP_CODE" -eq 200 ]; then
        STATUS="healthy"
        UPTIME=$(echo "$HTTP_BODY" | grep -o '"uptime_seconds":[0-9]*' | cut -d':' -f2)
        TOTAL_REQ=$(echo "$HTTP_BODY" | grep -o '"total_requests":[0-9]*' | cut -d':' -f2)
        AVG_LATENCY=$(echo "$HTTP_BODY" | grep -o '"average_latency_ms":[0-9.]*' | cut -d':' -f2)
        LAST_LATENCY=$(echo "$HTTP_BODY" | grep -o '"last_request_latency_ms":[0-9.]*' | cut -d':' -f2)

        echo "[ $TIMESTAMP ] [OK 200] Status: $STATUS | Latency: ${LATENCY_MS}ms | Total Requests: ${TOTAL_REQ:-0} | Avg Latency: ${AVG_LATENCY:-0}ms"

        # Export JSON metrics status file for dashboard consumption
        cat <<EOF > "$STATUS_FILE"
{
  "status": "$STATUS",
  "http_code": $HTTP_CODE,
  "check_timestamp": "$TIMESTAMP",
  "check_latency_ms": $LATENCY_MS,
  "uptime_seconds": ${UPTIME:-0},
  "total_requests": ${TOTAL_REQ:-0},
  "average_latency_ms": ${AVG_LATENCY:-0},
  "last_request_latency_ms": ${LAST_LATENCY:-$LATENCY_MS}
}
EOF
    else
        STATUS="unhealthy"
        echo "[ $TIMESTAMP ] [ERROR ${HTTP_CODE:-000}] Target $API_URL is DOWN or unreachable! Latency: ${LATENCY_MS}ms"

        cat <<EOF > "$STATUS_FILE"
{
  "status": "$STATUS",
  "http_code": ${HTTP_CODE:-0},
  "check_timestamp": "$TIMESTAMP",
  "check_latency_ms": $LATENCY_MS,
  "uptime_seconds": 0,
  "total_requests": 0,
  "average_latency_ms": 0,
  "last_request_latency_ms": 0
}
EOF
    fi

    sleep $CHECK_INTERVAL
done
