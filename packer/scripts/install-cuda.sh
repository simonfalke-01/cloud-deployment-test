#!/bin/bash
set -euxo pipefail

# If not running as root, prefix privileged commands with sudo
if [ "$EUID" -ne 0 ]; then
  SUDO='sudo'
else
  SUDO=''
fi

export DEBIAN_FRONTEND=noninteractive
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

echo "==> Preparing build environment for NVIDIA DKMS (using ${SUDO:-root})"

# retry apt-get update a few times in case another process holds the lock briefly
for i in 1 2 3 4 5; do
  if $SUDO apt-get update -y; then
    break
  fi
  echo "apt-get update failed, retrying ($i/5)..."
  sleep 2
done

# Install core build tools and DKMS BEFORE installing nvidia-dkms
$SUDO apt-get install -y --no-install-recommends \
  build-essential \
  dkms \
  linux-headers-$(uname -r) \
  linux-headers-generic \
  pkg-config \
  make \
  ca-certificates \
  wget \
  gnupg \
  lsb-release || { echo "apt-get install core build tools failed"; exit 1; }

# Ensure a stable gcc/g++ (Ubuntu 22.04 ships gcc-11)
$SUDO apt-get install -y --no-install-recommends gcc-11 g++-11

# Make gcc/g++ point to gcc-11/g++-11 (so DKMS uses gcc-11)
$SUDO update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100
$SUDO update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 100

# sanity check: kernel headers must exist
if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
  echo "ERROR: kernel headers for $(uname -r) are missing."
  ls -l /lib/modules || true
  exit 1
fi

echo "==> Installing NVIDIA CUDA apt repository keyring"
CUDA_KEYRING_PKG="cuda-keyring_1.1-1_all.deb"
wget -q "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/${CUDA_KEYRING_PKG}"
$SUDO dpkg -i "${CUDA_KEYRING_PKG}"
rm -f "${CUDA_KEYRING_PKG}"

$SUDO apt-get update -y

echo "==> Installing NVIDIA drivers, utils, CUDA toolkit, cuDNN"
$SUDO apt-get install -y --no-install-recommends \
  nvidia-dkms-535 \
  nvidia-utils-535 \
  nvidia-driver-535 \
  cuda-toolkit-12-4 \
  libcudnn8 \
  libcudnn8-dev || {
    echo "apt install failed; show dpkg status for nvidia packages"
    $SUDO dpkg -l | egrep -i 'nvidia|cuda' || true
    exit 1
}

echo "==> DKMS status:"
$SUDO dkms status || true

# If module build previously failed, show last part of make.log to surface errors in packer logs
if [ -f "/var/lib/dkms/nvidia/535.261.03/build/make.log" ]; then
  echo "==== NVIDIA DKMS make.log (last 200 lines) ===="
  $SUDO tail -n 200 /var/lib/dkms/nvidia/535.261.03/build/make.log || true
fi

# Set environment vars system-wide (idempotent)
$SUDO bash -c "grep -qxF 'export PATH=/usr/local/cuda-12.4/bin:\$PATH' /etc/environment || echo 'export PATH=/usr/local/cuda-12.4/bin:\$PATH' >> /etc/environment"
$SUDO bash -c "grep -qxF 'export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:\$LD_LIBRARY_PATH' /etc/environment || echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:\$LD_LIBRARY_PATH' >> /etc/environment"
$SUDO bash -c "grep -qxF 'export CUDA_HOME=/usr/local/cuda-12.4' /etc/environment || echo 'export CUDA_HOME=/usr/local/cuda-12.4' >> /etc/environment"

$SUDO ln -sf /usr/local/cuda-12.4 /usr/local/cuda

echo "==> Done. If DKMS built correctly the nvidia module will be available after a reboot. Check 'dkms status' and /var/lib/dkms/.../build/make.log for errors."
