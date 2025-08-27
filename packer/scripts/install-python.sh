#!/bin/bash
set -e

echo "Installing Python and ML dependencies..."

# Install Python 3.10 and pip
sudo apt-get update
sudo apt-get install -y python3.10 python3.10-venv python3.10-dev python3-pip
sudo apt-get install -y build-essential cmake git

# Set Python 3.10 as default
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1

# Upgrade pip
python3 -m pip install --upgrade pip

# Install RAPIDS cuML and other GPU-accelerated libraries
# Note: Using conda for RAPIDS as it's the recommended approach
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/miniconda3
rm Miniconda3-latest-Linux-x86_64.sh

# Add conda to PATH
echo 'export PATH="/opt/miniconda3/bin:$PATH"' | sudo tee -a /etc/environment
export PATH="/opt/miniconda3/bin:$PATH"

# Create conda environment with CUDA support
/opt/miniconda3/bin/conda create -n rapids -y python=3.10
/opt/miniconda3/bin/conda install -n rapids -c rapidsai -c conda-forge -c nvidia \
    cuml=24.02 cupy cudatoolkit=12.0 -y

# Install additional Python packages
/opt/miniconda3/bin/conda install -n rapids -y \
    flask gunicorn numpy pandas matplotlib seaborn plotly \
    scikit-learn opencv psutil GPUtil

# Install additional packages with pip in the rapids environment
/opt/miniconda3/bin/conda run -n rapids pip install \
    flask-cors flask-socketio eventlet \
    pillow requests boto3

# Make conda available to all users
sudo chown -R root:root /opt/miniconda3
sudo chmod -R 755 /opt/miniconda3

# Create activation script
sudo tee /usr/local/bin/activate-rapids << 'EOF'
#!/bin/bash
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate rapids
exec "$@"
EOF

sudo chmod +x /usr/local/bin/activate-rapids

echo "Python and ML dependencies installation completed."