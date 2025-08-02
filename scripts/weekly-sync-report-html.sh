#!/bin/bash

REPORT_FILE="/tmp/weekly-sync-report.html"
LOG_FILE="/var/log/pcloud-sync/ssd-sync.log"
REALTIME_LOG="/var/log/pcloud-sync/realtime.log"
EMAIL="altandphone01@gmail.com"

# Function to get status color and icon
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

# Generate HTML report
cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { background-color: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #667eea; background-color: #f8f9fa; }
        .good { color: #28a745; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .critical { color: #dc3545; font-weight: bold; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background-color: white; border-radius: 5px; min-width: 200px; }
        .code { background-color: #f1f1f1; padding: 10px; border-radius: 5px; font-family: monospace; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #667eea; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Weekly Sync Report - Raspberry Pi Emergency Backup</h1>
            <p><strong>Generated:</strong> $(date)</p>
            <p><strong>Hostname:</strong> $(hostname) | <strong>Uptime:</strong> $(uptime | awk '{print $3,$4}')</p>
        </div>

        <div class="section">
            <h2>🔧 System Status</h2>
            <div class="metric">
                <strong>Load Average:</strong> $CURRENT_LOAD<br>
                <span class="$(echo $(get_status $CURRENT_LOAD load) | awk '{print tolower($2)}')">$(get_status $CURRENT_LOAD load)</span>
            </div>
            <div class="metric">
                <strong>SSD Usage:</strong> ${SSD_USAGE}%<br>
                <span class="$(echo $(get_status $SSD_USAGE disk) | awk '{print tolower($2)}')">$(get_status $SSD_USAGE disk)</span>
            </div>
            <div class="metric">
                <strong>Error Count:</strong> $ERROR_COUNT<br>
                <span class="$([ $ERROR_COUNT -eq 0 ] && echo 'good' || ([ $ERROR_COUNT -lt 10 ] && echo 'warning' || echo 'critical'))">$([ $ERROR_COUNT -eq 0 ] && echo '🟢 NO ERRORS' || ([ $ERROR_COUNT -lt 10 ] && echo '🟡 SOME ERRORS' || echo '🔴 MANY ERRORS'))</span>
            </div>
        </div>

        <div class="section">
            <h2>⚙️ Services Status</h2>
            <table>
                <tr><th>Service</th><th>Status</th><th>Health</th></tr>
                <tr>
                    <td>NAS Mount Service</td>
                    <td>$POMME_STATUS</td>
                    <td><span class="$(echo $(get_status $POMME_STATUS service) | awk '{print tolower($2)}')">$(get_status $POMME_STATUS service)</span></td>
                </tr>
                <tr>
                    <td>Real-time Monitor</td>
                    <td>$REALTIME_STATUS</td>
                    <td><span class="$(echo $(get_status $REALTIME_STATUS service) | awk '{print tolower($2)}')">$(get_status $REALTIME_STATUS service)</span></td>
                </tr>
                <tr>
                    <td>Sync Timer</td>
                    <td>$TIMER_STATUS</td>
                    <td><span class="$(echo $(get_status $TIMER_STATUS service) | awk '{print tolower($2)}')">$(get_status $TIMER_STATUS service)</span></td>
                </tr>
            </table>
        </div>

        <div class="section">
            <h2>💾 Storage Status</h2>
            <div class="code">
$(df -h | grep -E "(pomme|ssd)" | while read line; do
    usage=$(echo $line | awk '{print $5}' | sed 's/%//')
    mount=$(echo $line | awk '{print $6}')
    size=$(echo $line | awk '{print $2}')
    used=$(echo $line | awk '{print $3}')
    avail=$(echo $line | awk '{print $4}')
    
    if [ $usage -lt 80 ]; then
        status="🟢"
    elif [ $usage -lt 90 ]; then
        status="🟡"
    else
        status="🔴"
    fi
    
    echo "$status $mount: $used/$size used ($usage%) - $avail available"
done)
            </div>
        </div>

        <div class="section">
            <h2>📈 Recent Activity</h2>
            <p><strong>Recent Sync Operations:</strong></p>
            <div class="code">
$(tail -n 20 "$LOG_FILE" 2>/dev/null | grep "INFO" | tail -5 || echo "No recent sync activity found")
            </div>
            
            <p><strong>File Changes:</strong> $(tail -n 100 "$REALTIME_LOG" 2>/dev/null | wc -l || echo "0") recent changes detected</p>
        </div>

        $(if [ $ERROR_COUNT -gt 0 ]; then
            echo '<div class="section">'
            echo '<h2>⚠️ Recent Errors</h2>'
            echo '<div class="code">'
            grep -i "error\|failed" "$LOG_FILE" 2>/dev/null | tail -5 || echo "No errors found"
            echo '</div>'
            echo '</div>'
        fi)

        <div class="section">
            <h2>⏰ Next Scheduled Sync</h2>
            <div class="code">
$(sudo systemctl list-timers | grep pcloud || echo "Timer not found")
            </div>
        </div>

        <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
            <p>Emergency Backup System | Raspberry Pi | $(date '+%Y-%m-%d %H:%M')</p>
        </div>
    </div>
</body>
</html>
EOF

# Send HTML email
if [ -f "$REPORT_FILE" ]; then
    (
        echo "MIME-Version: 1.0"
        echo "Content-Type: text/html; charset=UTF-8"
        echo "Subject: 📊 Weekly Sync Report - $(hostname) - $(date '+%Y-%m-%d')"
        echo "To: $EMAIL"
        echo ""
        cat "$REPORT_FILE"
    ) | msmtp "$EMAIL"
    
    echo "$(date): HTML weekly report sent to $EMAIL" >> /var/log/pcloud-sync/weekly-reports.log
    rm "$REPORT_FILE"
else
    echo "$(date): Failed to generate HTML report" >> /var/log/pcloud-sync/weekly-reports.log
fi
