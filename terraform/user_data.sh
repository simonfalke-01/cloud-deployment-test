#!/bin/bash
set -e

# Update system and wait for cloud-init to complete
/usr/bin/cloud-init status --wait

# Set environment variables
export AWS_DEFAULT_REGION=${region}
export ENABLE_AUTO_SHUTDOWN=${enable_auto_shutdown}
export AUTO_SHUTDOWN_TIMEOUT=${auto_shutdown_timeout}

# Source CUDA environment
source /etc/environment

# Wait for NVIDIA driver to be available
echo "Waiting for NVIDIA driver to be ready..."
while ! nvidia-smi &>/dev/null; do
    echo "Still waiting for NVIDIA driver..."
    sleep 5
done
echo "NVIDIA driver is ready"

# Start CloudWatch agent with our configuration
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Start services
systemctl start nginx
systemctl start gpu-demo

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Check if services are running
systemctl is-active --quiet nginx && echo "Nginx is running" || echo "Nginx failed to start"
systemctl is-active --quiet gpu-demo && echo "GPU Demo app is running" || echo "GPU Demo app failed to start"

# Set up auto-shutdown if enabled
if [ "${enable_auto_shutdown}" = "true" ]; then
    # Create auto-shutdown script
    cat > /usr/local/bin/auto-shutdown-check.sh << 'EOF'
#!/bin/bash
# Check if there's been recent activity (HTTP requests in last ${auto_shutdown_timeout} minutes)
TIMEOUT_MINUTES=${auto_shutdown_timeout}
LOG_FILE="/var/log/nginx/access.log"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Check for recent access logs
if [ -f "$LOG_FILE" ]; then
    RECENT_ACTIVITY=$(find $LOG_FILE -newermt "$TIMEOUT_MINUTES minutes ago" -exec wc -l {} \; 2>/dev/null | head -1 | awk '{print $1}')
    
    if [ -z "$RECENT_ACTIVITY" ] || [ "$RECENT_ACTIVITY" -eq 0 ]; then
        echo "No activity detected in the last $TIMEOUT_MINUTES minutes. Shutting down instance..."
        logger "Auto-shutdown: No activity detected in the last $TIMEOUT_MINUTES minutes"
        aws ec2 stop-instances --instance-ids $INSTANCE_ID --region ${region}
    else
        echo "Activity detected ($RECENT_ACTIVITY requests). Instance will remain running."
    fi
else
    echo "Log file not found: $LOG_FILE"
fi
EOF
    
    chmod +x /usr/local/bin/auto-shutdown-check.sh
    
    # Set up cron job for auto-shutdown check (every 5 minutes)
    echo "*/5 * * * * root /usr/local/bin/auto-shutdown-check.sh >/dev/null 2>&1" > /etc/cron.d/auto-shutdown
    
    # Restart cron to pick up the new job
    systemctl restart cron
    
    echo "Auto-shutdown configured with ${auto_shutdown_timeout} minute timeout"
fi

# Log completion
echo "User data script completed successfully at $(date)" | tee -a /var/log/user-data.log