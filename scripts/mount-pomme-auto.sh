#!/bin/bash

# Auto-mount script for systemd (no prompts)
BASE_MOUNT="/mnt/pomme"
LOG_FILE="/var/log/pcloud-sync/mount.log"
CRED_FILE="/home/vincent/.smbcredentials"

# Your NAS settings (update these)
NAS_IP="192.168.1.90"
USERNAME="prosync"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if credentials file exists
if [ ! -f "$CRED_FILE" ]; then
    log_msg "ERROR: Credentials file not found at $CRED_FILE"
    exit 1
fi

# Define shares
declare -a SHARES=("VRL" "ODV" "VRL.media")

log_msg "INFO: Starting auto-mount of Pomme shares"

# Mount all shares
for SHARE_NAME in "${SHARES[@]}"; do
    MOUNT_POINT="$BASE_MOUNT/$SHARE_NAME"
    
    # Create mount point
    sudo mkdir -p "$MOUNT_POINT"
    
    # Skip if already mounted
    if mountpoint -q "$MOUNT_POINT"; then
        log_msg "INFO: $SHARE_NAME already mounted"
        continue
    fi
    
    log_msg "INFO: Mounting share //$NAS_IP/$SHARE_NAME to $MOUNT_POINT"
    
    # Try mounting
    if sudo mount -t cifs "//$NAS_IP/$SHARE_NAME" "$MOUNT_POINT" \
        -o credentials="$CRED_FILE",vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0777,dir_mode=0777; then
        log_msg "INFO: Successfully mounted $SHARE_NAME"
    else
        log_msg "ERROR: Failed to mount $SHARE_NAME"
    fi
done

log_msg "INFO: Auto-mount completed"
