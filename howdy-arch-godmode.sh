#!/bin/bash

set -e

# Automatically detect Python version
PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_SITE="/usr/lib/python${PYVER}/site-packages"
HOWDY_DIR="/usr/lib/howdy"

# Function to patch cv2 import using absolute path
patch_cv2_import() {
  local file="$1"
  local cv2_block='import sys
import importlib.util
import os

cv2_path = "/usr/lib/python3.13/site-packages/cv2/cv2.abi3.so"
spec = importlib.util.spec_from_file_location("cv2", cv2_path)
cv2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cv2)'

  echo "🛠️  Patching cv2 import in $file..."

  if grep -q "import cv2" "$file"; then
    sudo sed -i '/import cv2/d' "$file"

    sudo awk -v code="$cv2_block" '
      BEGIN { inserted=0 }
      {
        if (!inserted && $0 ~ /^import/ || $0 ~ /^from/ || $0 ~ /^#/ || $0 ~ /^$/) {
          print $0
        } else if (!inserted) {
          print code
          print ""
          print $0
          inserted=1
        } else {
          print $0
        }
      }
    ' "$file" | sudo tee "$file.new" > /dev/null && sudo mv "$file.new" "$file"

    echo "✅ Patched: $file"
  else
    echo "⚠️  No 'import cv2' found in $file — skipped"
  fi
}

echo "🚀 Starting Howdy Arch/EndeavourOS Godmode installation"

echo "📦 Installing system dependencies..."
sudo pacman -S --needed --noconfirm \
  cmake make gcc linux-headers \
  python python-pip python-wheel \
  python-setuptools pam boost \
  libevdev libinih \
  python-numpy python-pillow python-pyudev python-click \
  v4l-utils meson ninja

echo "📦 Installing Python modules..."
sudo pip3 install opencv-python face_recognition --break-system-packages

echo "✅ dlib already installed, skipping build"

echo "🐼 Cloning and building Howdy..."
cd $(xdg-user-dir DOWNLOAD)
rm -rf howdy || true
git clone https://github.com/boltgolt/howdy.git
cd howdy
meson setup builddir --prefix=/usr
cd builddir
ninja
sudo ninja install

echo "🔗 Linking pam_howdy.so to standard PAM path..."
sudo mkdir -p /lib/security
sudo cp -f /usr/lib/security/pam_howdy.so /lib/security/pam_howdy.so || echo "PAM module already linked"

echo "🧠 Patching Howdy modules with absolute cv2 import..."
patch_cv2_import $HOWDY_DIR/compare.py
patch_cv2_import $HOWDY_DIR/snapshot.py

echo "📥 Downloading required dlib models..."
sudo mkdir -p /usr/share/dlib-data
cd /tmp
wget -O shape_predictor_5_face_landmarks.dat.bz2 https://github.com/davisking/dlib-models/raw/master/shape_predictor_5_face_landmarks.dat.bz2
bunzip2 shape_predictor_5_face_landmarks.dat.bz2
sudo mv shape_predictor_5_face_landmarks.dat /usr/share/dlib-data/

wget https://github.com/davisking/dlib-models/raw/master/dlib_face_recognition_resnet_model_v1.dat.bz2
bunzip2 dlib_face_recognition_resnet_model_v1.dat.bz2
sudo mv dlib_face_recognition_resnet_model_v1.dat /usr/share/dlib-data/

echo "🔧 Enabling Howdy in all PAM-enabled login points..."
PAM_FILES=(
  /etc/pam.d/sudo
  /etc/pam.d/gdm-password
  /etc/pam.d/gdm-fingerprint
  /etc/pam.d/login
  /etc/pam.d/system-auth
  /etc/pam.d/su
)

for pam_file in "${PAM_FILES[@]}"; do
  if [[ -f "$pam_file" ]]; then
    if ! grep -q "pam_howdy.so" "$pam_file"; then
      echo "📌 Inserting into $pam_file"
      sudo sed -i '1i auth sufficient pam_howdy.so' "$pam_file"
    else
      echo "✅ Already present in $pam_file"
    fi
  else
    echo "⚠️  PAM file $pam_file not found — skipping"
  fi
done

echo "✅ INSTALLATION COMPLETE"
echo "------------------------------------"
echo "📸 Add your face:       sudo howdy add"
echo "🔁 Test login via face: sudo -k && sudo echo \"Entering like a king\""
echo "🧠 dlib version:        $(python3 -c 'import dlib; print(dlib.__version__)')"
echo "💥 See you in the BIOS, Duda."
