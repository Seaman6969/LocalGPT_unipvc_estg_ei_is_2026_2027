#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_NAME="LocalGPT"
OUTPUT="${APP_NAME}-x86_64.AppImage"

echo ">>> Sourcing virtual environment"
source v/bin/activate

# Prevent Python from writing .pyc files
export PYTHONDONTWRITEBYTECODE=1

echo ">>> Ensuring pyproject.toml"
if [ ! -f "pyproject.toml" ]; then
    cat > pyproject.toml << 'EOF'
[project]
name = "LocalGPT"
version = "1"
description = "Local procurement assistant"
requires-python = ">=3.10"
dependencies = [
    "chromadb",
    "requests",
    "pypdf",
    "openpyxl",
    "pandas",
    "python-docx",
    "ollama",
    "scipy",
]

[project.scripts]
localgpt = "main:main"

[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[tool.setuptools]
py-modules = ["main"]
packages = [
    "attachments",
    "chat",
    "config",
    "gui",
    "local",
    "ollama",
    "rag",
    "utils",
]
EOF
fi

echo ">>> Cleaning previous build artifacts"
rm -rf build dist "${APP_NAME}.AppDir" "${OUTPUT}"

if [ ! -x "./appimagetool" ]; then
    if [ -f "../appimagetool" ]; then
        cp ../appimagetool ./appimagetool
    fi
    chmod +x ./appimagetool 2>/dev/null || true
fi

echo ">>> Building binary with PyInstaller"
python -B -m PyInstaller --clean --noconfirm localgpt.spec

echo ">>> Assembling AppDir"
mkdir -p "${APP_NAME}.AppDir/usr/bin"
mkdir -p "${APP_NAME}.AppDir/usr/share/icons/hicolor/256x256/apps"
cp -a dist/localgpt/* "${APP_NAME}.AppDir/usr/bin/"
cp assets/icon.png "${APP_NAME}.AppDir/${APP_NAME}.png"
cp assets/icon.png "${APP_NAME}.AppDir/usr/share/icons/hicolor/256x256/apps/${APP_NAME}.png"

cat > "${APP_NAME}.AppDir/${APP_NAME}.desktop" << 'EOF'
[Desktop Entry]
Name=LocalGPT
Comment=Local procurement assistant
Exec=localgpt
Icon=LocalGPT
Type=Application
Categories=Utility;
Terminal=false
EOF

cat > "${APP_NAME}.AppDir/AppRun" << 'EOF'
#!/bin/sh
export PYTHONDONTWRITEBYTECODE=1
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/localgpt" "$@"
EOF

chmod +x "${APP_NAME}.AppDir/AppRun"
chmod +x "${APP_NAME}.AppDir/usr/bin/localgpt"

echo ">>> Generating AppImage"
ARCH=x86_64 ./appimagetool --appimage-extract-and-run "${APP_NAME}.AppDir" "${OUTPUT}"

echo ">>> Cleaning temporary bytecode if any"
find . -not -path "./v*" -not -path "./${APP_NAME}.AppDir*" -not -path "./dist*" -not -path "./build*" \( -name "*pycache*" -o -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true

echo
echo ">>> Build complete: $(pwd)/${OUTPUT}"
