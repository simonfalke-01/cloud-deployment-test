#!/bin/bash
set -e

echo "Installing NVIDIA drivers and CUDA 12..."

# Install NVIDIA driver repository
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# Install NVIDIA driver
sudo apt-get install -y nvidia-driver-535 nvidia-utils-535

# Install CUDA toolkit 12
sudo apt-get install -y cuda-toolkit-12-4

# Install cuDNN for deep learning
sudo apt-get install -y libcudnn8 libcudnn8-dev

# Set up environment variables
echo 'export PATH=/usr/local/cuda-12.4/bin:$PATH' | sudo tee -a /etc/environment
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH' | sudo tee -a /etc/environment
echo 'export CUDA_HOME=/usr/local/cuda-12.4' | sudo tee -a /etc/environment

# Create symlinks for CUDA
sudo ln -sf /usr/local/cuda-12.4 /usr/local/cuda

# Verify installation will work after reboot
echo "CUDA installation completed. Driver and toolkit will be available after reboot."

# Clean up
rm -f cuda-keyring_1.1-1_all.deb