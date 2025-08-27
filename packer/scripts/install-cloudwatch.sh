#!/bin/bash
set -e

echo "Installing CloudWatch agent..."

# Download and install CloudWatch agent
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f amazon-cloudwatch-agent.deb

# Create CloudWatch agent configuration
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "GPU-Demo/EC2",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": true
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent",
                    "mem_available_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "gpu-demo-nginx-access",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log",
                        "log_group_name": "gpu-demo-nginx-error",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/opt/gpu-demo/logs/app.log",
                        "log_group_name": "gpu-demo-app",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    }
}
EOF

# Create custom metrics script for GPU monitoring
sudo tee /usr/local/bin/gpu-metrics.sh << 'EOF'
#!/bin/bash
# Custom script to send GPU metrics to CloudWatch

if command -v nvidia-smi &> /dev/null; then
    # Get GPU utilization
    GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
    GPU_MEM_UTIL=$(nvidia-smi --query-gpu=utilization.memory --format=csv,noheader,nounits | head -1)
    GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1)
    
    # Get instance metadata
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    
    # Send metrics to CloudWatch
    aws cloudwatch put-metric-data \
        --namespace "GPU-Demo/GPU" \
        --metric-data MetricName=GPUUtilization,Value=$GPU_UTIL,Unit=Percent,Dimensions=InstanceId=$INSTANCE_ID \
        --region $REGION
        
    aws cloudwatch put-metric-data \
        --namespace "GPU-Demo/GPU" \
        --metric-data MetricName=GPUMemoryUtilization,Value=$GPU_MEM_UTIL,Unit=Percent,Dimensions=InstanceId=$INSTANCE_ID \
        --region $REGION
        
    aws cloudwatch put-metric-data \
        --namespace "GPU-Demo/GPU" \
        --metric-data MetricName=GPUTemperature,Value=$GPU_TEMP,Unit=Count,Dimensions=InstanceId=$INSTANCE_ID \
        --region $REGION
fi
EOF

sudo chmod +x /usr/local/bin/gpu-metrics.sh

# Create cron job for GPU metrics
sudo tee /etc/cron.d/gpu-metrics << 'EOF'
# Send GPU metrics to CloudWatch every minute
* * * * * root /usr/local/bin/gpu-metrics.sh >/dev/null 2>&1
EOF

# Enable CloudWatch agent service
sudo systemctl enable amazon-cloudwatch-agent

echo "CloudWatch agent installation completed."