#!/bin/bash

REPORT_FILE="/tmp/weekly-sync-report.txt"
LOG_FILE="/var/log/pcloud-sync/ssd-sync.log"
REALTIME_LOG="/var/log/pcloud-sync/realtime.log"
EMAIL="altandphone01@gmail.com"

# Function to get status
get_status() {
    local value=$1
    local type=$2
    
    case $type in
        "load")
            if (( $(echo "$value < 2.0" | bc -l) )); then
                echo "🟢 GOOD"
            elif (( $(echo "$value < 4.0" | bc -l) )); then
                echo "🟡 WARNING"
            else
                echo "🔴 CRITICAL"
            fi
            ;;
        "disk")
            if (( value < 80 )); then
                echo "🟢 GOOD"
            elif (( value < 90 )); then
                echo "🟡 WARNING"  
            else
                echo "🔴 CRITICAL"
            fi
            ;;
        "service")
            if [[ "$value" == "active" ]]; then
                echo "🟢 RUNNING"
            elif [[ "$value" == "inactive" ]]; then
                echo "🟡 STOPPED"
            else
                echo "🔴 FAILED"
            fi
            ;;
        "errors")
            if (( value == 0 )); then
                echo "🟢 NO ERRORS"
            elif (( value < 10 )); then
                echo "🟡 SOME ERRORS"
            else
                echo "🔴 MANY ERRORS"
            fi
            ;;
    esac
}

# Get current metrics
CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
SSD_USAGE=$(df -h /mnt/ssd | tail -1 | awk '{print $5}' | sed 's/%//')
ERROR_COUNT=$(grep -i "error\|failed" "$LOG_FILE" 2>/dev/null | wc -l)

# Service statuses
POMME_STATUS=$(systemctl is-active pomme-mount.service)
REALTIME_STATUS=$(systemctl is-active realtime-monitor.service)
TIMER_STATUS=$(systemctl is-active pcloud-sync.timer)

# Generate report
cat > "$REPORT_FILE" << EOF
📊 WEEKLY SYNC REPORT - RASPBERRY PI EMERGENCY BACKUP
================================================================
Generated: $(date)
Hostname: $(hostname)
Uptime: $(uptime)

🔧 SYSTEM STATUS
================================================================
Load Average: $CURRENT_LOAD - $(get_status $CURRENT_LOAD load)
SSD Usage: ${SSD_USAGE}% - $(get_status $SSD_USAGE disk)
Error Count: $ERROR_COUNT - $(get_status $ERROR_COUNT errors)

⚙️ SERVICES STATUS  
================================================================
NAS Mount Service:    $POMME_STATUS - $(get_status $POMME_STATUS service)
Real-time Monitor:    $REALTIME_STATUS - $(get_status $REALTIME_STATUS service)  
Sync Timer:           $TIMER_STATUS - $(get_status $TIMER_STATUS service)

💾 STORAGE STATUS
================================================================
$(df -h | grep -E "(pomme|ssd)" | while read line; do
    usage=$(echo $line | awk '{print $5}' | sed 's/%//')
    mount=$(echo $line | awk '{print $6}')
    size=$(echo $line | awk '{print $2}')
    used=$(echo $line | awk '{print $3}')
    avail=$(echo $line | awk '{print $4}')
    status=$(get_status $usage disk)
    echo "$mount: $used/$size ($usage%) - $status"
done)

📈 SYNC ACTIVITY (Last 7 Days)
================================================================
Recent Sync Operations:
$(tail -n 1000 "$LOG_FILE" 2>/dev/null | grep "$(date '+%Y/%m')" | tail -10 || echo "No recent sync logs found")

File Changes Detected:
$(tail -n 1000 "$REALTIME_LOG" 2>/dev/null | wc -l || echo "0") recent file changes detected

$(if [ $ERROR_COUNT -gt 0 ]; then
echo "⚠️ ERRORS (Last 7 Days)"
echo "================================================================"
grep -i "error\|failed\|warning" "$LOG_FILE" 2>/dev/null | tail -10 || echo "No errors found"
echo ""
fi)

🔗 MOUNT STATUS
================================================================
$(mount | grep -E "(pomme|ssd)" | while read line; do
    device=$(echo $line | awk '{print $1}')
    mount=$(echo $line | awk '{print $3}')
    type=$(echo $line | awk '{print $5}')
    echo "🟢 $device -> $mount ($type)"
done)

⏰ NEXT SCHEDULED SYNC
================================================================
$(sudo systemctl list-timers | grep pcloud || echo "🟡 Timer not found")

📁 LOG FILE SIZES
================================================================
$(ls -lh /var/log/pcloud-sync/ 2>/dev/null | tail -n +2 | awk '{print $9 ": " $5}' || echo "Log directory not found")

================================================================
Report Status: 🟢 COMPLETED SUCCESSFULLY
Emergency Backup System: $([ "$POMME_STATUS" = "active" ] && [ "$REALTIME_STATUS" = "active" ] && [ "$TIMER_STATUS" = "active" ] && echo "🟢 FULLY OPERATIONAL" || echo "🟡 PARTIAL OPERATION")
EOF

# Send email
if [ -f "$REPORT_FILE" ]; then
    mail -s "📊 Weekly Sync Report - $(hostname) - $(date '+%Y-%m-%d')" "$EMAIL" < "$REPORT_FILE"
    echo "$(date): Color-coded weekly report sent to $EMAIL" >> /var/log/pcloud-sync/weekly-reports.log
    rm "$REPORT_FILE"
else
    echo "$(date): Failed to generate report" >> /var/log/pcloud-sync/weekly-reports.log
fi
