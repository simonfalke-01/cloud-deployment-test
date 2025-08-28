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
sudo bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/miniconda3
rm Miniconda3-latest-Linux-x86_64.sh

# Add conda to PATH
echo 'export PATH="/opt/miniconda3/bin:$PATH"' | sudo tee -a /etc/environment
export PATH="/opt/miniconda3/bin:$PATH"

# Configure conda to avoid ToS issues and use conda-forge as default
/opt/miniconda3/bin/conda config --system --set auto_activate_base false
/opt/miniconda3/bin/conda config --system --add channels conda-forge
/opt/miniconda3/bin/conda config --system --add channels nvidia
/opt/miniconda3/bin/conda config --system --add channels rapidsai
/opt/miniconda3/bin/conda config --system --set channel_priority strict
/opt/miniconda3/bin/conda config --system --remove channels defaults 2>/dev/null || true

# Initialize conda for all users
/opt/miniconda3/bin/conda init bash
sudo /opt/miniconda3/bin/conda init bash

# Create conda environment with CUDA support using explicit channels
/opt/miniconda3/bin/conda create -n rapids -y python=3.10 --override-channels -c conda-forge
/opt/miniconda3/bin/conda install -n rapids --override-channels -c rapidsai -c conda-forge -c nvidia \
    cuml=24.02 cupy cudatoolkit=12.0 -y

# Install additional Python packages
/opt/miniconda3/bin/conda install -n rapids -y --override-channels -c conda-forge \
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