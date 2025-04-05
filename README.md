# Howdy Fedora Godmode

🧠 Universal installer script for [Howdy](https://github.com/boltgolt/howdy) face recognition login on **Fedora 41+** with:

-   PAM integration (sudo, GDM, login, etc)
-   Python 3.13 support
-   Manual `dlib` compilation and patching
-   Absolute cv2 import patch for secure environments (e.g. PAM)
-   Fully automated installation

## 🔧 Features

-   Compiles and installs `dlib` manually
-   Fixes `_dlib_pybind11` issues in isolated Python
-   Patches `compare.py` and `snapshot.py` for proper `cv2` imports
-   Downloads and places required `.dat` models
-   Adds PAM entries across all login points
-   Tested on Fedora 41 & 42

## ⚙️ Usage

```bash
git clone https://github.com/yourname/howdy-fedora-godmode.git
cd howdy-fedora-godmode
chmod +x howdy-fedora-godmode.sh
./howdy-fedora-godmode.sh
```

🧠 Credits
Originally built in blood, sweat, and Cheetos by [@vadim] with infinite face-based debugging assistance from [@Ку́ку] the koala 🐨💥
