#!/bin/bash

REPORT_FILE="/tmp/weekly-sync-report.txt"
LOG_FILE="/var/log/pcloud-sync/ssd-sync.log"
REALTIME_LOG="/var/log/pcloud-sync/realtime.log"
EMAIL="altandphone01@gmail.com"  # Change this to your actual email

# Generate report
cat > "$REPORT_FILE" << EOF
Weekly Sync Report - Raspberry Pi Emergency Backup
Generated: $(date)
Hostname: $(hostname)
Uptime: $(uptime)

=== SYSTEM STATUS ===
Load Average: $(uptime | awk -F'load average:' '{print $2}')
Disk Usage:
$(df -h | grep -E "(pomme|ssd|root)")

=== SYNC SERVICES STATUS ===
$(sudo systemctl status pomme-mount.service --no-pager -l | head -10)

$(sudo systemctl status realtime-monitor.service --no-pager -l | head -10)

$(sudo systemctl status pcloud-sync.timer --no-pager -l | head -10)

=== SYNC ACTIVITY (Last 7 Days) ===
Recent Sync Operations:
$(grep "$(date -d '7 days ago' '+%Y/%m/%d')" "$LOG_FILE" 2>/dev/null | tail -20 || echo "No recent sync logs found")

File Changes Detected:
$(tail -n 1000 "$REALTIME_LOG" 2>/dev/null | grep "$(date -d '7 days ago' '+%b')" | wc -l || echo "0") file changes detected this week

=== ERRORS (Last 7 Days) ===
$(grep -i "error\|failed\|warning" "$LOG_FILE" 2>/dev/null | tail -10 || echo "No errors found")

=== MOUNT STATUS ===
$(mount | grep -E "(pomme|ssd)")

=== NEXT SCHEDULED SYNC ===
$(sudo systemctl list-timers | grep pcloud)

=== LOG FILE SIZES ===
$(ls -lh /var/log/pcloud-sync/ 2>/dev/null || echo "Log directory not found")

Report completed successfully.
EOF

# Send email
if [ -f "$REPORT_FILE" ]; then
    mail -s "Weekly Sync Report - $(hostname) - $(date '+%Y-%m-%d')" "$EMAIL" < "$REPORT_FILE"
    echo "$(date): Weekly report sent to $EMAIL" >> /var/log/pcloud-sync/weekly-reports.log
    rm "$REPORT_FILE"
else
    echo "$(date): Failed to generate report" >> /var/log/pcloud-sync/weekly-reports.log
fi
