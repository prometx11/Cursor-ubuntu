#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
APP_INSTALL_DIR="/opt/Cursor/app"
CURSOR_BASE_DIR="/opt/Cursor" # Contains APP_INSTALL_DIR
LAUNCHER_PATH="/usr/local/bin/cursor"
INSTALL_EXTRACT_PARENT_DIR="/tmp" # Parent for unique extraction dirs
DEBUG_EXTRACT_BASE_DIR="/tmp/cursor_debug_extraction"

BUNDLED_ICON_FILENAME="co.anysphere.cursor.png"
BUNDLED_DESKTOP_FILENAME="cursor.desktop"
SYSTEM_DESKTOP_ENTRY_PATH="/usr/share/applications/${BUNDLED_DESKTOP_FILENAME}"
FINAL_ICON_PATH="${APP_INSTALL_DIR}/${BUNDLED_ICON_FILENAME}"
EXTRACTED_DIR_NAME="squashfs-root" # Default name AppImage creates

# --- Helper Functions (ensure_sudo, check_dependencies, cleanup_previous_installation) ---
ensure_sudo() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This script needs to run some commands with sudo."
    echo "Please enter your password if prompted."
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  fi
}

check_dependencies() {
    echo "Checking dependencies..."
    local missing_deps=0
    if ! command -v curl &> /dev/null; then
        echo "curl is not installed. Attempting to install..."
        sudo apt-get update && sudo apt-get install -y curl || missing_deps=1
    fi
    if ! command -v sed &> /dev/null; then
        echo "sed is not installed. Attempting to install..."
        sudo apt-get update && sudo apt-get install -y sed || missing_deps=1
    fi
    if ! dpkg -s libfuse2 &> /dev/null && ! apt list --installed 2>/dev/null | grep -q "^libfuse2/"; then
        echo "libfuse2 is not installed (often required for AppImages). Attempting to install..."
        sudo apt-get update && sudo apt-get install -y libfuse2 || missing_deps=1
        if dpkg -s libfuse2 &> /dev/null || apt list --installed 2>/dev/null | grep -q "^libfuse2/"; then
            echo "✅ libfuse2 installed successfully."
        else
            echo "⚠️ Failed to install libfuse2. AppImage might not run."
        fi
    else
        echo "ℹ️ libfuse2 is already installed."
    fi
    if [ "$missing_deps" -ne 0 ]; then
        echo "❌ Some dependencies could not be installed. Please install them manually and try again."
        exit 1
    fi
    echo "✅ Dependencies satisfied."
}

cleanup_previous_installation() {
    echo "Cleaning up any previous installation remnants..."
    sudo rm -f "$LAUNCHER_PATH"
    sudo rm -f "$SYSTEM_DESKTOP_ENTRY_PATH"
    if [ -d "$CURSOR_BASE_DIR" ]; then
        echo "Removing old $CURSOR_BASE_DIR..."
        sudo rm -rf "$CURSOR_BASE_DIR"
    fi
    if [ -d "./${EXTRACTED_DIR_NAME}" ]; then
        echo "Removing local ./$EXTRACTED_DIR_NAME..."
        sudo rm -rf "./${EXTRACTED_DIR_NAME}"
    fi
    # General cleanup for any leftover unique extract dirs in /tmp
    # This is a bit broad but helps if script exited prematurely
    sudo find "$INSTALL_EXTRACT_PARENT_DIR" -maxdepth 1 -name "cursor_extract.*" -type d -exec rm -rf {} + 2>/dev/null || true
    if [ -d "${DEBUG_EXTRACT_BASE_DIR}" ]; then
        echo "Removing previous debug extraction at ${DEBUG_EXTRACT_BASE_DIR}..."
        sudo rm -rf "${DEBUG_EXTRACT_BASE_DIR}"
    fi
}

debug_download_and_extract() {
    echo "--- Debug: Download & Extract AppImage Only ---"
    read -p "Enter Cursor AppImage download URL: " CURSOR_DOWNLOAD_URL
    local temp_appimage
    temp_appimage=$(mktemp --suffix=.AppImage)

    echo "Downloading Cursor AppImage to $temp_appimage..."
    curl -L "$CURSOR_DOWNLOAD_URL" -o "$temp_appimage"
    if [ ! -s "$temp_appimage" ]; then
        echo "❌ Download failed or AppImage is empty. Please check URL and network."
        rm -f "$temp_appimage"
        return 1
    fi
    chmod +x "$temp_appimage"
    echo "✅ AppImage downloaded to $temp_appimage."

    echo "Preparing debug extraction directory: $DEBUG_EXTRACT_BASE_DIR"
    if [ -d "$DEBUG_EXTRACT_BASE_DIR" ]; then
        echo "Removing previous debug extraction at $DEBUG_EXTRACT_BASE_DIR..."
        rm -rf "$DEBUG_EXTRACT_BASE_DIR"
    fi
    mkdir -p "$DEBUG_EXTRACT_BASE_DIR"

    echo "Extracting AppImage to $DEBUG_EXTRACT_BASE_DIR..."
    local current_dir extract_output
    current_dir=$(pwd)
    cd "$DEBUG_EXTRACT_BASE_DIR"
    # Run --appimage-extract without arguments; it will create 'squashfs-root'
    extract_output=$("$temp_appimage" --appimage-extract 2>&1)
    local extract_status=$?
    local extracted_path="${DEBUG_EXTRACT_BASE_DIR}/${EXTRACTED_DIR_NAME}"
    cd "$current_dir"

    if [ $extract_status -ne 0 ] || [ ! -d "$extracted_path" ] || [ -z "$(ls -A "$extracted_path")" ]; then
        echo "❌ Failed to extract AppImage or extracted directory is empty."
        echo "   Extraction command exit status: $extract_status"
        echo "   Extraction command output: $extract_output"
        echo "   The (potentially problematic) AppImage is still at: $temp_appimage"
        echo "   Attempted extraction into: $extracted_path"
        # rm -f "$temp_appimage" # Keep AppImage for manual inspection
        return 1
    else
        echo "✅ AppImage extracted successfully!"
        echo "👉 You can inspect the contents at: $extracted_path"
        echo "   Look for '$BUNDLED_ICON_FILENAME', '$BUNDLED_DESKTOP_FILENAME', 'AppRun'."
    fi
    echo "Cleaning up downloaded AppImage file: $temp_appimage"
    rm -f "$temp_appimage"
    echo "--- Debugging step complete ---"
}


# --- Installation/Update Function ---
install_or_update_cursor() {
    local mode="$1" # "install" or "update"
    ensure_sudo

    if [ "$mode" = "install" ]; then
        echo "Installing Cursor AI IDE on Ubuntu..."
        check_dependencies
    else
        echo "Updating Cursor AI IDE..."
    fi

    read -p "Enter Cursor AppImage download URL: " CURSOR_DOWNLOAD_URL
    local temp_appimage
    temp_appimage=$(mktemp --suffix=.AppImage)
    echo "Downloading Cursor AppImage to $temp_appimage..."
    curl -L "$CURSOR_DOWNLOAD_URL" -o "$temp_appimage"
    if [ ! -s "$temp_appimage" ]; then
        echo "❌ Download failed or AppImage is empty. Please check URL and network."
        rm -f "$temp_appimage"
        exit 1
    fi
    chmod +x "$temp_appimage"
    echo "✅ AppImage downloaded."

    if [ "$mode" = "update" ] || [ -d "$APP_INSTALL_DIR" ]; then
        echo "Removing old application files from $APP_INSTALL_DIR for $mode..."
        sudo rm -rf "${APP_INSTALL_DIR:?}"/*
    fi
    sudo mkdir -p "$APP_INSTALL_DIR"

    echo "Preparing for AppImage extraction..."
    local current_dir extraction_work_dir extracted_content_source_path extract_output
    current_dir=$(pwd)
    # Create a unique temporary directory for this specific extraction
    extraction_work_dir=$(mktemp -d -p "$INSTALL_EXTRACT_PARENT_DIR" cursor_extract.XXXXXX)
    echo "Created temporary extraction working directory: $extraction_work_dir"

    cd "$extraction_work_dir"
    echo "Extracting AppImage into $extraction_work_dir ..."
    # Run --appimage-extract without arguments; it will create 'squashfs-root' inside extraction_work_dir
    extract_output=$("$temp_appimage" --appimage-extract 2>&1)
    local extract_status=$?
    cd "$current_dir"

    extracted_content_source_path="${extraction_work_dir}/${EXTRACTED_DIR_NAME}"

    if [ $extract_status -ne 0 ] || [ ! -d "$extracted_content_source_path" ] || [ -z "$(ls -A "$extracted_content_source_path")" ]; then
        echo "❌ Failed to extract AppImage or extracted content directory is empty."
        echo "   Extraction command exit status: $extract_status"
        echo "   Extraction command output: $extract_output"
        echo "   Expected extracted content at: $extracted_content_source_path"
        echo "   The downloaded AppImage was: $temp_appimage (will be cleaned up)"
        sudo rm -rf "$extraction_work_dir" # Clean up the unique temp dir
        rm -f "$temp_appimage"
        exit 1
    fi
    echo "✅ AppImage extracted successfully to $extracted_content_source_path"

    echo "Copying application files from $extracted_content_source_path to $APP_INSTALL_DIR..."
    sudo rsync -a --delete "${extracted_content_source_path}/" "$APP_INSTALL_DIR/"
    if [ -z "$(ls -A "$APP_INSTALL_DIR")" ]; then
        echo "❌ ERROR: $APP_INSTALL_DIR is empty after rsync."
        echo "   Source for rsync was: ${extracted_content_source_path}/"
        ls -lA "$extracted_content_source_path" # Show what was in the source
        sudo rm -rf "$extraction_work_dir"
        rm -f "$temp_appimage"
        exit 1
    fi
    echo "✅ Application files copied."

    # --- Verify bundled icon exists ---
    if [ ! -f "$FINAL_ICON_PATH" ]; then
        echo "❌ ERROR: Bundled icon '$BUNDLED_ICON_FILENAME' not found at '$FINAL_ICON_PATH'."
        local found_icon
        found_icon=$(find "$APP_INSTALL_DIR" -maxdepth 1 -iname "${BUNDLED_ICON_FILENAME}" -print -quit)
        if [ -n "$found_icon" ]; then
            echo "ℹ️  Found a similar icon: $found_icon. Consider updating BUNDLED_ICON_FILENAME."
        fi
    else
        echo "✅ Bundled icon found at $FINAL_ICON_PATH"
    fi

    # --- Create Custom Launcher Script ---
    echo "Creating $LAUNCHER_PATH launcher script..."
    sudo tee "$LAUNCHER_PATH" > /dev/null << EOF
#!/usr/bin/env sh
if [ "\$(id -u)" = "0" ]; then
    CAN_LAUNCH_AS_ROOT=
    for i in "\$@"
    do
        case "\$i" in
            --user-data-dir | --user-data-dir=* | --file-write | tunnel | serve-web )
                CAN_LAUNCH_AS_ROOT=1
            ;;
        esac
    done
    if [ -z \$CAN_LAUNCH_AS_ROOT ]; then
        echo "You are trying to start Cursor as a super user which isn't recommended. If this was intended, please add the argument \`--no-sandbox\` AND specify an alternate user data directory using the \`--user-data-dir\` argument." 1>&2
        exit 1
    fi
fi
CURSOR_APP_PATH="${APP_INSTALL_DIR}"
APP_EXECUTABLE="\$CURSOR_APP_PATH/AppRun"
if [ ! -f "\$APP_EXECUTABLE" ]; then
    echo "Error: Cursor AppRun not found at \$APP_EXECUTABLE" 1>&2
    exit 1
fi
# Execute AppRun in the background, detached from the terminal
# and immune to SIGHUP. Redirect stdout and stderr to /dev/null.
nohup "$APP_EXECUTABLE" "$@" >/dev/null 2>&1 &

# The script will now exit immediately after launching AppRun in the background.
exit 0 # Optional, as the script would exit anyway
EOF
    sudo chmod +x "$LAUNCHER_PATH"
    echo "✅ Launcher script created."

    # --- Fix chrome-sandbox Permissions ---
    echo "Searching for chrome-sandbox within $APP_INSTALL_DIR..."
    local sandbox_path
    sandbox_path=$(sudo find "$APP_INSTALL_DIR" -name chrome-sandbox -type f -print -quit 2>/dev/null)
    if [[ -n "$sandbox_path" && -f "$sandbox_path" ]]; then
        echo "Found chrome-sandbox at: $sandbox_path"
        echo "Fixing permissions on chrome-sandbox..."
        sudo chown root:root "$sandbox_path"
        sudo chmod 4755 "$sandbox_path"
        echo "✅ Sandbox permissions fixed."
    else
        echo "⚠️ Warning: chrome-sandbox not found within $APP_INSTALL_DIR."
    fi

    # --- Use Bundled .desktop File ---
    local source_desktop_file="${APP_INSTALL_DIR}/${BUNDLED_DESKTOP_FILENAME}"
    if [ ! -f "$source_desktop_file" ]; then
        echo "❌ ERROR: Bundled desktop file '$BUNDLED_DESKTOP_FILENAME' not found at '$source_desktop_file'."
        echo "   Skipping desktop entry creation."
    else
        echo "Using bundled .desktop file from $source_desktop_file"
        sudo cp "$source_desktop_file" "$SYSTEM_DESKTOP_ENTRY_PATH"
        echo "Modifying $SYSTEM_DESKTOP_ENTRY_PATH ..."
        local escaped_launcher_path
        escaped_launcher_path=$(printf '%s\n' "$LAUNCHER_PATH" | sed 's:[&/\]:\\&:g')
        sudo sed -i -E "s|^(Exec=)cursor(\s+.*)?$|\1${escaped_launcher_path}\2|" "$SYSTEM_DESKTOP_ENTRY_PATH"
        if [ -f "$FINAL_ICON_PATH" ]; then
            local escaped_final_icon_path
            escaped_final_icon_path=$(printf '%s\n' "$FINAL_ICON_PATH" | sed 's:[&/\]:\\&:g')
            sudo sed -i "s|^Icon=.*|Icon=${escaped_final_icon_path}|" "$SYSTEM_DESKTOP_ENTRY_PATH"
            echo "✅ Icon path updated in .desktop file."
        else
            echo "⚠️ Bundled icon not found, Icon= line in .desktop file not updated to absolute path."
        fi
        echo "✅ .desktop entry created and modified from bundled file."
        sudo update-desktop-database -q
        echo "✅ Desktop database updated."
    fi

    # --- Cleanup ---
    echo "Cleaning up temporary files..."
    sudo rm -rf "$extraction_work_dir" # Clean up the unique temp dir that contains squashfs-root
    rm -f "$temp_appimage"
    echo "✅ Cleanup complete."

    if [ "$mode" = "install" ]; then
        echo "✅ Cursor AI IDE installation complete. You can find it in your application menu."
    else
        echo "✅ Cursor AI IDE update complete. Please restart Cursor if it was running."
    fi
}

uninstall_cursor() {
    ensure_sudo
    echo "Uninstalling Cursor AI IDE..."
    cleanup_previous_installation
    echo "Updating desktop database..."
    sudo update-desktop-database -q
    echo "✅ Cursor AI IDE uninstallation complete."
}

# --- Main Menu ---
# (Menu remains the same)
echo "Cursor AI IDE Management Script"
echo "-------------------------------"
echo "Current system time: $(date)"
echo "Installation Directory: $APP_INSTALL_DIR"
echo "Launcher Path: $LAUNCHER_PATH"
echo ""
echo "1. Install Cursor"
echo "2. Update Cursor"
echo "3. Uninstall Cursor"
echo "4. Download & Extract AppImage Only (for debugging)"
echo "5. Exit"
read -p "Please choose an option (1-5): " choice

case $choice in
    1)
        if [ -f "$LAUNCHER_PATH" ] || [ -d "$APP_INSTALL_DIR" ]; then
            read -p "⚠️ Cursor seems to be already installed. Do you want to overwrite/reinstall? (y/N): " confirm_reinstall
            if [[ "$confirm_reinstall" =~ ^[Yy]$ ]]; then
                cleanup_previous_installation
                install_or_update_cursor "install"
            else
                echo "Aborting installation."
            fi
        else
            install_or_update_cursor "install"
        fi
        ;;
    2)
        if [ ! -f "$LAUNCHER_PATH" ] && [ ! -d "$APP_INSTALL_DIR" ]; then
             echo "❌ Cursor is not installed. Please choose the install option first."
             exit 1
        fi
        install_or_update_cursor "update"
        ;;
    3)
        if [ ! -f "$LAUNCHER_PATH" ] && [ ! -d "$APP_INSTALL_DIR" ]; then
             echo "❌ Cursor is not installed. Nothing to uninstall."
             exit 1
        fi
        uninstall_cursor
        ;;
    4)
        debug_download_and_extract
        ;;
    5)
        echo "Exiting."
        ;;
    *)
        echo "❌ Invalid option. Exiting."
        exit 1
        ;;
esac

exit 0
