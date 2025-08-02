#!/bin/bash

# realtime-monitor.sh - Separate script for the real-time file monitor
# This fixes the systemd service activation issue

LOG_FILE="/var/log/pcloud-sync/realtime.log"
BASE_MOUNT="/mnt/pomme"
SYNC_SCRIPT="/home/vincent/ssd-sync.sh"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - REALTIME: $1" | tee -a "$LOG_FILE"
}

log_msg "Starting real-time file monitor for $BASE_MOUNT"

# Check if base mount exists
if [ ! -d "$BASE_MOUNT" ]; then
    log_msg "ERROR: Base mount directory $BASE_MOUNT does not exist"
    exit 1
fi

# Check if any shares are mounted
MOUNTED_COUNT=$(find "$BASE_MOUNT" -maxdepth 1 -type d -exec mountpoint -q {} \; -print 2>/dev/null | grep -v "^$BASE_MOUNT$" | wc -l)

if [ "$MOUNTED_COUNT" -eq 0 ]; then
    log_msg "WARNING: No shares currently mounted, but starting monitor anyway"
fi

log_msg "Monitor started. Watching $MOUNTED_COUNT mounted shares"

# Start monitoring with inotifywait
inotifywait -m -r \
    -e modify,create,delete,move \
    --exclude "(#recycle|#snapshot|\.DS_Store|Thumbs\.db|\.Trash-|\.SynologyWorkingDirectory)" \
    "$BASE_MOUNT" 2>/dev/null | \
while read path action file; do
    # Log the file change
    log_msg "File change detected: $action $path$file"
    
    # Wait 15 seconds to batch changes
    sleep 15
    
    # Trigger background sync
    if [ -x "$SYNC_SCRIPT" ]; then
        log_msg "Triggering background sync due to file changes"
        "$SYNC_SCRIPT" --background >/dev/null 2>&1 &
    else
        log_msg "ERROR: Sync script not found or not executable: $SYNC_SCRIPT"
    fi
done

