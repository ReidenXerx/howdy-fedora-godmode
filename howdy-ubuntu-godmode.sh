#!/bin/bash

set -e

# Automatically detect Python version
PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_SITE="/usr/local/lib/python${PYVER}/dist-packages"

# Function to patch cv2 import using absolute path
patch_cv2_import() {
  local file="$1"
  local cv2_block='import sys
import importlib.util
import os

cv2_path = "/usr/local/lib/python'${PYVER}'/dist-packages/cv2/cv2.abi3.so"
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

echo "🚀 Starting Howdy Ubuntu/Mint Godmode installation"

# Ensure python symlink exists for meson
if [ ! -f "/usr/bin/python" ]; then
  echo "🔗 Creating /usr/bin/python symlink..."
  sudo ln -s /usr/bin/python3 /usr/bin/python
fi

echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y \
  cmake build-essential libopenblas-dev liblapack-dev \
  python3 python3-dev python3-pip python3-setuptools \
  libpam0g-dev libboost-all-dev \
  libevdev-dev libinih-dev \
  python3-numpy python3-pil python3-pyudev python3-click \
  v4l-utils meson ninja-build pkg-config \
  wget bzip2 git

echo "📦 Installing Python modules..."
# Install without upgrading system numpy
sudo pip3 install --no-deps opencv-python --break-system-packages
sudo pip3 install --no-deps face_recognition_models --break-system-packages
sudo pip3 install --no-deps face_recognition --break-system-packages

echo "🧱 Cloning and building dlib..."
cd ~/Downloads
rm -rf dlib || true
git clone https://github.com/davisking/dlib.git
cd dlib
mkdir -p build && cd build
cmake ..
cmake --build . --config Release
cd ..
sudo python3 setup.py install --set DLIB_USE_CUDA=0

echo "🔁 Ensuring dlib is accessible..."
sudo mkdir -p $PYTHON_SITE/dlib
if [ -d "/usr/local/lib/python${PYVER}/dist-packages/dlib" ]; then
  echo "✅ dlib installed correctly"
else
  echo "⚠️  Copying dlib files..."
  sudo cp -r /usr/local/lib/python${PYVER}/site-packages/dlib* $PYTHON_SITE/ 2>/dev/null || true
fi

# Find the _dlib_pybind11 .so file
DLIB_SO=$(find /usr/local/lib/python${PYVER} -name "_dlib_pybind11*.so" 2>/dev/null | head -1)
if [ -n "$DLIB_SO" ]; then
  DLIB_SO_NAME=$(basename "$DLIB_SO")
  sudo cp "$DLIB_SO" "$PYTHON_SITE/dlib/" 2>/dev/null || true
  
  echo "🛠 Creating dlib/__init__.py with absolute _dlib_pybind11 import..."
  sudo tee $PYTHON_SITE/dlib/__init__.py > /dev/null << EOF
import sys
import os
import importlib.util

so_path = os.path.join(os.path.dirname(__file__), '${DLIB_SO_NAME}')
spec = importlib.util.spec_from_file_location("_dlib_pybind11", so_path)
_dlib_pybind11 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(_dlib_pybind11)

globals().update({k: getattr(_dlib_pybind11, k) for k in dir(_dlib_pybind11) if not k.startswith("__")})
EOF
fi

echo "🐼 Cloning and building Howdy..."
cd ~/Downloads
rm -rf howdy || true
git clone https://github.com/boltgolt/howdy.git
cd howdy
meson setup builddir --prefix=/usr
cd builddir
ninja
sudo ninja install

echo "🔗 Linking pam_howdy.so to standard PAM path..."
sudo mkdir -p /lib/security
# Find where pam_howdy.so was installed
for path in /usr/lib/x86_64-linux-gnu/security /usr/lib/security /usr/local/lib/security; do
  if [ -f "$path/pam_howdy.so" ]; then
    sudo ln -sf "$path/pam_howdy.so" /lib/security/pam_howdy.so
    echo "✅ Linked PAM module from $path"
    break
  fi
done

echo "🧠 Patching Howdy modules with absolute cv2 import..."
# Find Howdy installation directory
for HOWDY_DIR in /usr/lib/x86_64-linux-gnu/howdy /usr/lib/howdy /usr/local/lib/howdy; do
  if [ -d "$HOWDY_DIR" ]; then
    echo "📍 Found Howdy at: $HOWDY_DIR"
    break
  fi
done

if [ -f "$HOWDY_DIR/compare.py" ]; then
  patch_cv2_import $HOWDY_DIR/compare.py
fi
if [ -f "$HOWDY_DIR/snapshot.py" ]; then
  patch_cv2_import $HOWDY_DIR/snapshot.py
fi

echo "📥 Downloading required dlib models..."
sudo mkdir -p /usr/share/dlib-data
cd /tmp
wget -O shape_predictor_5_face_landmarks.dat.bz2 https://github.com/davisking/dlib-models/raw/master/shape_predictor_5_face_landmarks.dat.bz2
bunzip2 -f shape_predictor_5_face_landmarks.dat.bz2
sudo mv shape_predictor_5_face_landmarks.dat /usr/share/dlib-data/

wget -O dlib_face_recognition_resnet_model_v1.dat.bz2 https://github.com/davisking/dlib-models/raw/master/dlib_face_recognition_resnet_model_v1.dat.bz2
bunzip2 -f dlib_face_recognition_resnet_model_v1.dat.bz2
sudo mv dlib_face_recognition_resnet_model_v1.dat /usr/share/dlib-data/

echo "🔧 Enabling Howdy in all PAM-enabled login points..."
PAM_FILES=(
  /etc/pam.d/sudo
  /etc/pam.d/gdm-password
  /etc/pam.d/lightdm
  /etc/pam.d/login
  /etc/pam.d/common-auth
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
echo "🧠 dlib version:        $(python3 -c 'import dlib; print(dlib.__version__)' 2>/dev/null || echo 'Check failed')"
echo "💥 Face recognition ready on Linux Mint!"
