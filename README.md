# Howdy Godmode

🧠 Universal installer scripts for [Howdy](https://github.com/boltgolt/howdy) face recognition login with:

-   PAM integration (sudo, GDM, LightDM, login, etc)
-   Python 3.12+ support
-   Manual `dlib` compilation and patching
-   Absolute cv2 import patch for secure environments (e.g. PAM)
-   Fully automated installation

## 🔧 Features

-   Compiles and installs `dlib` manually
-   Fixes `_dlib_pybind11` issues in isolated Python
-   Patches `compare.py` and `snapshot.py` for proper `cv2` imports
-   Downloads and places required `.dat` models
-   Adds PAM entries across all login points
-   Tested on:
    -   **Fedora** 41 & 42
    -   **Arch Linux** / EndeavourOS
    -   **Ubuntu** 22.04+ / **Linux Mint** 21+

## ⚙️ Usage

### Fedora 41+
```bash
git clone https://github.com/ReidenXerx/howdy-fedora-godmode.git
cd howdy-fedora-godmode
chmod +x howdy-fedora-godmode.sh
./howdy-fedora-godmode.sh
```

### Arch Linux / EndeavourOS
```bash
git clone https://github.com/ReidenXerx/howdy-fedora-godmode.git
cd howdy-fedora-godmode
chmod +x howdy-arch-godmode.sh
./howdy-arch-godmode.sh
```

### Ubuntu / Linux Mint / Pop!_OS
```bash
git clone https://github.com/ReidenXerx/howdy-fedora-godmode.git
cd howdy-fedora-godmode
chmod +x howdy-ubuntu-godmode.sh
./howdy-ubuntu-godmode.sh
```

## 📸 Post-Installation

```bash
sudo howdy add           # Add your face model
sudo howdy test          # Test face recognition
sudo howdy list          # List registered faces
sudo howdy config        # Edit configuration
```

🧠 Credits
Originally built in blood, sweat, and Cheetos by [@vadim] with infinite face-based debugging assistance from [@Ку́ку] the koala 🐨💥
