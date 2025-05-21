# Cursor-ubuntu
This is a guideline and script for installing or updating Cursor on Ubuntu.

## Prerequisites
- Ubuntu 22.04 or a compatible Linux distribution
- Internet connection
- `sudo` privileges
- `curl` (the script will attempt to install it if missing)
- `libfuse2` (the script will attempt to install it if missing, as it's often required for AppImages)

## Installation/Update Steps

1.  **Download the Management Script**
    * Clone this repository or download the `manage_cursor.sh` (or your chosen script name) file.
    * Make the script executable:
        ```bash
        chmod +x manage_cursor.sh
        ```

2.  **Run the Script**
    * Execute the script:
        ```bash
        ./manage_cursor.sh
        ```
    * The script will present a menu:
        * Choose '1' to **Install Cursor**.
        * Choose '2' to **Update Cursor**.

3.  **Follow Prompts:**
    * **For Installation:**
        * When prompted, enter the **direct download URL** for the Cursor Linux AppImage (e.g., from [Cursor's official download page](https://www.cursor.com/downloads)).
        * Enter the desired icon filename from the repository (e.g., `cursor-icon.png` or `cursor-black-icon.png`).
    * **For Update:**
        * When prompted, enter the **direct download URL** for the **new** Cursor Linux AppImage.

4.  **Launch Cursor**
    * After installation, you should find "Cursor AI IDE" in your application menu.
    * Alternatively, you can launch it from the terminal:
        ```bash
        /opt/Cursor/cursor.appimage --no-sandbox
        ```

## Script Functionality
The script will:
-   Offer to install or update Cursor.
-   **During Installation:**
    -   Check for and install `curl` if missing.
    -   Check for and install `libfuse2` if missing (important for running AppImages).
    -   Download the specified Cursor AppImage to `/opt/Cursor/cursor.appimage`.
    -   Make the AppImage executable.
    -   Download a chosen icon to `/opt/Cursor/cursor-icon.png`.
    -   Create a desktop entry (`/usr/share/applications/cursor.desktop`) for easy access.
-   **During Update:**
    -   Download the new Cursor AppImage, replacing the old one in `/opt/Cursor/`.
    -   Ensure the new AppImage is executable.

## Troubleshooting
If you encounter any issues:
1.  Ensure you have `sudo` privileges and an active internet connection.
2.  Verify that the AppImage download URL you provided is correct and accessible.
3.  Confirm the icon filename exists in the `images` directory of the `hieutt192/Cursor-ubuntu` GitHub repository.
4.  If Cursor fails to start after installation, ensure `libfuse2` was installed correctly. The script attempts this, but you can manually check/install with `sudo apt update && sudo apt install libfuse2`.
5.  Check script permissions (`chmod +x your_script_name.sh`).

## Uninstallation
To uninstall Cursor:
1.  Remove the application files:
    ```bash
    sudo rm -rf /opt/Cursor
    ```
2.  Remove the desktop entry:
    ```bash
    sudo rm -f /usr/share/applications/cursor.desktop
    ```