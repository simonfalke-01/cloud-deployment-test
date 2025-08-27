#!/bin/bash
set -e

echo "Setting up GPU demo application..."

# Create application directory
sudo mkdir -p /opt/gpu-demo
sudo cp -r /tmp/app/* /opt/gpu-demo/
sudo chown -R ubuntu:ubuntu /opt/gpu-demo
sudo chmod +x /opt/gpu-demo/*.py

# Create systemd service for the Flask app
sudo tee /etc/systemd/system/gpu-demo.service << 'EOF'
[Unit]
Description=GPU Performance Demo Web Application
After=network.target
Requires=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/gpu-demo
Environment=FLASK_ENV=production
Environment=PYTHONPATH=/opt/gpu-demo
ExecStart=/usr/local/bin/activate-rapids gunicorn --bind 127.0.0.1:5000 --workers 2 --timeout 120 --worker-class eventlet app:app
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=gpu-demo

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/opt/gpu-demo/logs
ReadWritePaths=/tmp

[Install]
WantedBy=multi-user.target
EOF

# Create logs directory
sudo mkdir -p /opt/gpu-demo/logs
sudo chown ubuntu:ubuntu /opt/gpu-demo/logs

# Create startup script that ensures CUDA is available
sudo tee /opt/gpu-demo/start.sh << 'EOF'
#!/bin/bash
# Wait for NVIDIA driver to be ready
while ! nvidia-smi &>/dev/null; do
    echo "Waiting for NVIDIA driver..."
    sleep 2
done

# Source CUDA environment
source /etc/environment

# Start the Flask application
exec /usr/local/bin/activate-rapids gunicorn --bind 127.0.0.1:5000 --workers 2 --timeout 120 --worker-class eventlet app:app
EOF

sudo chmod +x /opt/gpu-demo/start.sh

# Update the systemd service to use our startup script
sudo sed -i 's|ExecStart=.*|ExecStart=/opt/gpu-demo/start.sh|' /etc/systemd/system/gpu-demo.service

# Enable the service
sudo systemctl daemon-reload
sudo systemctl enable gpu-demo.service

# Create a script for manual service management
sudo tee /usr/local/bin/gpu-demo-ctl << 'EOF'
#!/bin/bash
case "$1" in
    start)
        sudo systemctl start gpu-demo nginx
        ;;
    stop)
        sudo systemctl stop gpu-demo nginx
        ;;
    restart)
        sudo systemctl restart gpu-demo nginx
        ;;
    status)
        sudo systemctl status gpu-demo nginx
        ;;
    logs)
        sudo journalctl -u gpu-demo -f
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/gpu-demo-ctl

echo "GPU demo application setup completed."