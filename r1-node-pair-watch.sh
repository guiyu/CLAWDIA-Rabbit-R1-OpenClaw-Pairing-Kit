#!/bin/bash
set -euo pipefail

# Node pair watcher for Linux

TIMEOUT_MINUTES=10
POLL_SECONDS=1
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.r1-pair-watch"
LOG_PATH="$LOG_DIR/r1-node-pair-watch.log"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --TimeoutMinutes) TIMEOUT_MINUTES="$2"; shift 2 ;;
        --PollSeconds) POLL_SECONDS="$2"; shift 2 ;;
        --LogPath) LOG_PATH="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Create log directory
mkdir -p "$(dirname "$LOG_PATH")"

log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_PATH"
}

log "watcher started timeout=${TIMEOUT_MINUTES}m poll=${POLL_SECONDS}s"

# Calculate deadline
START_TIME=$(date +%s)
END_TIME=$((START_TIME + TIMEOUT_MINUTES * 60))

echo "Starting pair watcher (timeout: ${TIMEOUT_MINUTES}m)..."

while true; do
    CURRENT_TIME=$(date +%s)
    if [[ $CURRENT_TIME -ge $END_TIME ]]; then
        log "timeout no pending node pair"
        echo "TIMEOUT"
        exit 2
    fi

    # Get pending pair requests
    RAW=$(openclaw gateway call node.pair.list --json 2>/dev/null || true)
    
    if [[ -n "$RAW" ]]; then
        # Parse JSON and iterate through pending requests
        PENDING_COUNT=$(echo "$RAW" | jq '.pending | length // 0' 2>/dev/null || echo 0)
        
        if [[ $PENDING_COUNT -gt 0 ]]; then
            echo "$RAW" | jq -c '.pending[]?' 2>/dev/null | while read -r item; do
                RID=$(echo "$item" | jq -r '.requestId // empty')
                NAME=$(echo "$item" | jq -r '.displayName // "unknown"')
                PLATFORM=$(echo "$item" | jq -r '.platform // "unknown"')
                NODEID=$(echo "$item" | jq -r '.nodeId // empty')
                
                if [[ -n "$RID" && "$RID" != "null" ]]; then
                    log "pending requestId=$RID displayName=$NAME platform=$PLATFORM nodeId=$NODEID"
                    
                    # Approve the pair request
                    APPROVE_JSON="{\"requestId\":\"$RID\"}"
                    RESP=$(openclaw gateway call node.pair.approve --params "$APPROVE_JSON" --json 2>&1 || true)
                    
                    log "approve requestId=$RID result=$RESP"
                    echo "APPROVED:$RID"
                    exit 0
                fi
            done
            
            # Check if we exited successfully
            if [[ $? -eq 0 ]]; then
                exit 0
            fi
        fi
    fi

    sleep "$POLL_SECONDS"
done
