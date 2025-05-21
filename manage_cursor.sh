#!/bin/bash

# --- Global Variables ---
CURSOR_INSTALL_DIR="/opt/Cursor"
APPIMAGE_FILENAME="cursor.AppImage" # Standardized filename
ICON_FILENAME_ON_DISK="cursor-icon.png" # Standardized local icon name

APPIMAGE_PATH="${CURSOR_INSTALL_DIR}/${APPIMAGE_FILENAME}"
ICON_PATH="${CURSOR_INSTALL_DIR}/${ICON_FILENAME_ON_DISK}"
DESKTOP_ENTRY_PATH="/usr/share/applications/cursor.desktop"

# --- Installation Function ---
installCursor() {
    # Check if the AppImage already exists using the global path
    if ! [ -f "$APPIMAGE_PATH" ]; then
        echo "Installing Cursor AI IDE on Ubuntu..."

        # 📝 Enter the AppImage download URL
        read -p "Enter Cursor AppImage download URL: " CURSOR_DOWNLOAD_URL
        # 📝 Enter the icon file name to download (e.g., cursor-icon.png or cursor-black-icon.png)
        read -p "Enter icon filename from GitHub (e.g., cursor-icon.png): " ICON_NAME_FROM_GITHUB

        # Construct Icon URL for downloading
        ICON_DOWNLOAD_URL="https://raw.githubusercontent.com/hieutt192/Cursor-ubuntu/main/images/$ICON_NAME_FROM_GITHUB"

        # --- Dependency Checks ---
        # Install curl if not installed
        if ! command -v curl &> /dev/null; then
            echo "curl is not installed. Installing..."
            sudo apt-get update
            sudo apt-get install -y curl
        fi

        # Check and install libfuse2 if not installed
        if ! dpkg -s libfuse2 &> /dev/null && ! apt list --installed 2>/dev/null | grep -q "^libfuse2/"; then
            echo "libfuse2 is not installed, which is often required for AppImages."
            echo "Installing libfuse2..."
            sudo apt-get update
            sudo apt-get install -y libfuse2
            if dpkg -s libfuse2 &> /dev/null || apt list --installed 2>/dev/null | grep -q "^libfuse2/"; then
                echo "✅ libfuse2 installed successfully."
            else
                echo "⚠️  Failed to install libfuse2. AppImage might not run."
            fi
        else
            echo "ℹ️ libfuse2 is already installed."
        fi
        # --- End Dependency Checks ---

        # Create install directory if not exists
        echo "Creating installation directory ${CURSOR_INSTALL_DIR}..."
        sudo mkdir -p "$CURSOR_INSTALL_DIR"

        # Download Cursor AppImage using global APPIMAGE_PATH
        echo "Downloading Cursor AppImage to $APPIMAGE_PATH..."
        sudo curl -L "$CURSOR_DOWNLOAD_URL" -o "$APPIMAGE_PATH"
        echo "Making AppImage executable..."
        sudo chmod +x "$APPIMAGE_PATH"

        # Download Cursor icon using global ICON_PATH
        echo "Downloading Cursor icon to $ICON_PATH..."
        sudo curl -L "$ICON_DOWNLOAD_URL" -o "$ICON_PATH"

        # Create a .desktop entry for Cursor using global paths
        echo "Creating .desktop entry for Cursor..."
        sudo bash -c "cat > \"$DESKTOP_ENTRY_PATH\"" <<EOL
[Desktop Entry]
Name=Cursor AI IDE
Exec=$APPIMAGE_PATH --no-sandbox
Icon=$ICON_PATH
Type=Application
Categories=Development;
EOL

        echo "✅ Cursor AI IDE installation complete. You can find it in your application menu."
    else
        # Use global APPIMAGE_PATH in the message
        echo "ℹ️ Cursor AI IDE seems to be already installed at $APPIMAGE_PATH."
        echo "If you want to update, please choose the update option."
    fi
}

# --- Update Function ---
updateCursor() {
    # Uses global APPIMAGE_PATH
    if [ -f "$APPIMAGE_PATH" ]; then
        echo "Updating Cursor AI IDE..."

        # 📝 Enter the AppImage download URL
        read -p "Enter new Cursor AppImage download URL: " CURSOR_DOWNLOAD_URL

        # Download new Cursor AppImage using global APPIMAGE_PATH
        echo "Downloading new Cursor AppImage to $APPIMAGE_PATH..."
        sudo curl -L "$CURSOR_DOWNLOAD_URL" -o "$APPIMAGE_PATH"
        echo "Making new AppImage executable..."
        sudo chmod +x "$APPIMAGE_PATH"

        echo "✅ Cursor AI IDE update complete. Please restart Cursor if it was running."
    else
        # Use global APPIMAGE_PATH in the message
        echo "❌ Cursor AI IDE is not installed at $APPIMAGE_PATH. Please choose the install option first."
    fi
}

# --- Main Menu ---
echo "Cursor AI IDE Management"
echo "------------------------"
echo "1. Install Cursor"
echo "2. Update Cursor"
read -p "Please choose an option (1 or 2): " choice

case $choice in
    1)
        installCursor
        ;;
    2)
        updateCursor
        ;;
    *)
        echo "❌ Invalid option. Exiting."
        exit 1
        ;;
esac

exit 0