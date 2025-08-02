#!/bin/bash

# Mount Multiple Pomme Shares script
BASE_MOUNT="/mnt/pomme"
LOG_FILE="/var/log/pcloud-sync/mount.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Get NAS IP and credentials once
read -p "Enter your Synology NAS IP address: " NAS_IP
read -p "Enter your prosync-user username: " USERNAME
read -s -p "Enter your prosync-user password: " PASSWORD
echo

# Create credentials file
CRED_FILE="/home/vincent/.smbcredentials"
cat > "$CRED_FILE" << EOL
username=$USERNAME
password=$PASSWORD
domain=WORKGROUP
EOL

chmod 600 "$CRED_FILE"

# Define your specific shares
declare -a SHARES=("VRL" "ODV" "VRL.media")

# Ask user which shares to mount
echo "Available shares to sync:"
for i in "${!SHARES[@]}"; do
    echo "$((i+1)). ${SHARES[$i]}"
done

echo "Enter the numbers of shares you want to sync (space-separated, e.g., '1 2 3' for all):"
read -a SELECTED_INDICES

# Mount selected shares
for index in "${SELECTED_INDICES[@]}"; do
    share_index=$((index-1))
    if [[ $share_index -ge 0 && $share_index -lt ${#SHARES[@]} ]]; then
        SHARE_NAME="${SHARES[$share_index]}"
        MOUNT_POINT="$BASE_MOUNT/$SHARE_NAME"
        
        # Create mount point
        sudo mkdir -p "$MOUNT_POINT"
        
        log_msg "INFO: Mounting share //$NAS_IP/$SHARE_NAME to $MOUNT_POINT"
        
        # Try multiple SMB versions
        if sudo mount -t cifs "//$NAS_IP/$SHARE_NAME" "$MOUNT_POINT" \
            -o credentials="$CRED_FILE",vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0777,dir_mode=0777; then
            log_msg "INFO: Successfully mounted $SHARE_NAME with SMB 3.0"
            echo "✅ SUCCESS: $SHARE_NAME mounted at $MOUNT_POINT (SMB 3.0)"
        elif sudo mount -t cifs "//$NAS_IP/$SHARE_NAME" "$MOUNT_POINT" \
            -o credentials="$CRED_FILE",vers=2.1,uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0777,dir_mode=0777; then
            log_msg "INFO: Successfully mounted $SHARE_NAME with SMB 2.1"
            echo "✅ SUCCESS: $SHARE_NAME mounted at $MOUNT_POINT (SMB 2.1)"
        elif sudo mount -t cifs "//$NAS_IP/$SHARE_NAME" "$MOUNT_POINT" \
            -o credentials="$CRED_FILE",vers=2.0,uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0777,dir_mode=0777; then
            log_msg "INFO: Successfully mounted $SHARE_NAME with SMB 2.0"
            echo "✅ SUCCESS: $SHARE_NAME mounted at $MOUNT_POINT (SMB 2.0)"
        else
            log_msg "ERROR: Failed to mount $SHARE_NAME with all SMB versions"
            echo "❌ ERROR: Failed to mount $SHARE_NAME"
        fi
    fi
done

echo ""
echo "Mounted shares:"
mount | grep "$BASE_MOUNT"
