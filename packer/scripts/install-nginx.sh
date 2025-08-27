#!/bin/bash
set -e

echo "Installing and configuring nginx..."

# Install nginx
sudo apt-get update
sudo apt-get install -y nginx

# Create nginx configuration for the GPU demo app
sudo tee /etc/nginx/sites-available/gpu-demo << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support for real-time updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeout settings for long-running GPU operations
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Serve static files directly
    location /static {
        alias /opt/gpu-demo/static;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host $host;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/gpu-demo /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t

# Enable nginx service
sudo systemctl enable nginx

echo "Nginx installation and configuration completed."