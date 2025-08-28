#!/bin/bash
set -euxo pipefail

# noninteractive so apt won't prompt during packer runs
export DEBIAN_FRONTEND=noninteractive
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

echo "==> Preparing build environment for NVIDIA DKMS"

apt-get update -y

# Install core build tools and DKMS BEFORE installing nvidia-dkms
apt-get install -y --no-install-recommends \
  build-essential \
  dkms \
  linux-headers-$(uname -r) \
  linux-headers-generic \
  pkg-config \
  make \
  ca-certificates \
  wget \
  gnupg \
  lsb-release

# Ensure a stable gcc/g++ (Ubuntu 22.04 ships gcc-11)
apt-get install -y --no-install-recommends gcc-11 g++-11
# Make gcc/g++ point to gcc-11/g++-11 (so DKMS uses gcc-11)
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 100

# Confirm kernel headers present (fail early if they aren't)
if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
  echo "ERROR: kernel headers for $(uname -r) are missing."
  ls -l /lib/modules || true
  exit 1
fi

echo "==> Installing NVIDIA CUDA apt repository keyring"
# download keyring and configure repo
CUDA_KEYRING_PKG="cuda-keyring_1.1-1_all.deb"
wget -q "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/${CUDA_KEYRING_PKG}"
dpkg -i "${CUDA_KEYRING_PKG}"
rm -f "${CUDA_KEYRING_PKG}"

apt-get update -y

# Install drivers + toolkit. Install DKMS package names directly so build happens while headers/tools exist.
# Keep --no-install-recommends minimal in AMI builds but include nvidia-utils for testing.
apt-get install -y --no-install-recommends \
  nvidia-dkms-535 \
  nvidia-utils-535 \
  nvidia-driver-535 \
  cuda-toolkit-12-4 \
  libcudnn8 \
  libcudnn8-dev || {
    echo "apt install failed; show dpkg status for nvidia packages"
    dpkg -l | egrep -i 'nvidia|cuda' || true
    exit 1
}

# Sanity: check dkms status and kernel module
dkms status || true

# If module build previously failed, print make.log for debug
if grep -q "bad exit status" /var/log/dpkg.log 2>/dev/null || [ -f "/var/lib/dkms/nvidia/535.261.03/build/make.log" ]; then
  echo "==== NVIDIA DKMS make.log (last 200 lines) ===="
  sudo tail -n 200 /var/lib/dkms/nvidia/535.261.03/build/make.log || true
fi

# Set environment vars system-wide
grep -qxF 'export PATH=/usr/local/cuda-12.4/bin:$PATH' /etc/environment || echo 'export PATH=/usr/local/cuda-12.4/bin:$PATH' | tee -a /etc/environment
grep -qxF 'export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH' /etc/environment || echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH' | tee -a /etc/environment
grep -qxF 'export CUDA_HOME=/usr/local/cuda-12.4' /etc/environment || echo 'export CUDA_HOME=/usr/local/cuda-12.4' | tee -a /etc/environment

# Create symlink
ln -sf /usr/local/cuda-12.4 /usr/local/cuda

echo "CUDA/NVIDIA install finished. If the DKMS build succeeded the nvidia module should be available after reboot."
