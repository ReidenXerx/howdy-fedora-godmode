
#!/bin/bash

set -e

# Automatically detect Python version
PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_SITE="/usr/lib64/python${PYVER}/site-packages"
HOWDY_DIR="/usr/lib64/howdy"

# Function to patch cv2 import using absolute path
patch_cv2_import() {
  local file="$1"
  local cv2_block='import sys
import importlib.util
import os

cv2_path = "/usr/local/lib64/python3.13/site-packages/cv2/cv2.abi3.so"
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

echo "🚀 Starting Howdy Fedora Godmode installation"

echo "📦 Installing system dependencies..."
sudo dnf install -y \
  cmake make gcc gcc-c++ kernel-devel \
  python3 python3-devel python3-pip python3-wheel \
  python3-setuptools pam-devel boost-devel \
  libevdev-devel inih-devel \
  python3-numpy python3-pillow python3-pyudev python3-click \
  v4l-utils

echo "📦 Installing Python modules..."
sudo pip3 install opencv-python face_recognition --break-system-packages

echo "🧱 Cloning and building dlib..."
cd ~/Downloads
rm -rf dlib || true
git clone https://github.com/davisking/dlib.git
cd dlib
mkdir build && cd build
cmake ..
cmake --build . --config Release
cd ..
sudo python3 setup.py install --set DLIB_USE_CUDA=0

echo "🔁 Moving dlib to system site-packages..."
sudo mkdir -p $PYTHON_SITE/dlib
sudo cp -r /usr/local/lib64/python${PYVER}/site-packages/dlib* $PYTHON_SITE/
sudo cp /usr/local/lib64/python${PYVER}/site-packages/_dlib_pybind11*.so $PYTHON_SITE/dlib/

echo "🛠 Creating dlib/__init__.py with absolute _dlib_pybind11 import..."
sudo tee $PYTHON_SITE/dlib/__init__.py > /dev/null << EOF
import sys
import os
import importlib.util

so_path = os.path.join(os.path.dirname(__file__), '_dlib_pybind11.cpython-313-x86_64-linux-gnu.so')
spec = importlib.util.spec_from_file_location("_dlib_pybind11", so_path)
_dlib_pybind11 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(_dlib_pybind11)

globals().update({k: getattr(_dlib_pybind11, k) for k in dir(_dlib_pybind11) if not k.startswith("__")})
EOF

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
sudo cp /usr/local/lib64/security/pam_howdy.so /usr/lib64/security/
sudo ln -sf /usr/lib64/security/pam_howdy.so /lib/security/pam_howdy.so

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
  /etc/pam.d/password-auth
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
