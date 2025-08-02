#!/bin/bash

# High-performance SSD-based sync
BASE_MOUNT="/mnt/pomme"
SSD_SYNC="/mnt/ssd/pomme-sync"
REMOTE_BASE="cloud:prosync"
LOG_FILE="/var/log/pcloud-sync/ssd-sync.log"
PID_FILE="/tmp/ssd-sync.pid"
SCREEN_NAME="ssd-sync"

# Much higher performance settings thanks to SSD
RSYNC_OPTS="--bwlimit=50000 --modify-window=2"
RCLONE_OPTS="--bwlimit=50M --checkers=8 --transfers=4"
EXCLUSIONS="--exclude=#recycle --exclude=#snapshot --exclude=.DS_Store --exclude=Thumbs.db --exclude=.Trash-* --exclude=.SynologyWorkingDirectory"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
show_status() {
    if [ -f "/tmp/ssd-sync.pid" ]; then
        if ps -p $(cat "/tmp/ssd-sync.pid") > /dev/null 2>&1; then
            echo "✅ SSD sync is running (PID: $(cat /tmp/ssd-sync.pid))"
        else
            echo "❌ No SSD sync running"
            rm -f "/tmp/ssd-sync.pid"  # Clean up stale PID file
        fi
    else
        echo "❌ No SSD sync running"
    fi
    
    # Show recent activity regardless
    echo "Recent logs:"
    tail -5 /var/log/pcloud-sync/ssd-sync.log 2>/dev/null || echo "No logs yet"
    
    # Show systemd service status
    echo ""
    echo "Systemd service status:"
    if systemctl is-active pcloud-sync.service >/dev/null 2>&1; then
        echo "🔄 Systemd sync service is active"
    else
        echo "💤 Systemd sync service is idle"
    fi
    
    # Show next timer
    echo ""
    echo "Next scheduled sync:"
    systemctl list-timers | grep pcloud | head -1 || echo "Timer not found"
}

run_background() {
    if screen -list | grep -q "$SCREEN_NAME"; then
        echo "❌ SSD sync already running!"
        exit 1
    fi
    echo "🚀 Starting high-speed SSD sync..."
    screen -dmS "$SCREEN_NAME" bash -c "$0 --internal-sync"
    echo "✅ SSD sync started!"
}

case "$1" in
    --background|-b) run_background; exit 0 ;;
    --status|-s) show_status; exit 0 ;;
    --attach|-a) screen -r "$SCREEN_NAME" 2>/dev/null || echo "No session found"; exit 0 ;;
    --stop) screen -S "$SCREEN_NAME" -X quit 2>/dev/null; pkill -f "ssd-sync"; rm -f "$PID_FILE"; echo "Stopped"; exit 0 ;;
    --internal-sync) ;;
    "") ;;
esac

if [ -f "$PID_FILE" ]; then
    if ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
        log_msg "ERROR: Sync already running"
        exit 1
    fi
    rm -f "$PID_FILE"
fi

echo $$ > "$PID_FILE"
log_msg "INFO: Starting high-speed SSD sync"

MOUNTED_SHARES=$(find "$BASE_MOUNT" -maxdepth 1 -type d -exec mountpoint -q {} \; -print 2>/dev/null | grep -v "^$BASE_MOUNT$")

if [ -z "$MOUNTED_SHARES" ]; then
    log_msg "ERROR: No shares mounted"
    rm -f "$PID_FILE"
    exit 1
fi

# Process shares with much higher performance
for MOUNT_PATH in $MOUNTED_SHARES; do
    SHARE_NAME=$(basename "$MOUNT_PATH")
    SSD_PATH="$SSD_SYNC/$SHARE_NAME"
    REMOTE_PATH="$REMOTE_BASE/$SHARE_NAME"
    
    log_msg "INFO: High-speed processing: $SHARE_NAME"
    
    # Check load (higher threshold now)
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    if (( $(echo "$LOAD > 3.0" | bc -l) )); then
        log_msg "WARN: Load is $LOAD, brief wait..."
        sleep 15
    fi
    
    # High-speed sync to SSD
    log_msg "INFO: Fast sync $SHARE_NAME to SSD (50MB/s)"
    nice -n 10 rsync -av --delete $EXCLUSIONS $RSYNC_OPTS "$MOUNT_PATH/" "$SSD_PATH/" >> "$LOG_FILE" 2>&1
    
    # High-speed upload to pCloud
    log_msg "INFO: Fast upload $SHARE_NAME to pCloud (50MB/s, 4 transfers)"
    nice -n 10 rclone sync "$SSD_PATH/" "$REMOTE_PATH" $RCLONE_OPTS --log-file="$LOG_FILE" --log-level INFO
    
    # Download changes from pCloud
    log_msg "INFO: Download pCloud changes for $SHARE_NAME"
    nice -n 10 rclone sync "$REMOTE_PATH" "$SSD_PATH/" $RCLONE_OPTS --log-file="$LOG_FILE" --log-level INFO
    
    # Sync back to NAS
    log_msg "INFO: Sync $SHARE_NAME back to NAS"
    nice -n 10 rsync -av --delete $EXCLUSIONS $RSYNC_OPTS "$SSD_PATH/" "$MOUNT_PATH/" >> "$LOG_FILE" 2>&1
    
    log_msg "INFO: Completed high-speed sync for $SHARE_NAME"
done

log_msg "INFO: High-speed SSD sync completed"
rm -f "$PID_FILE"
