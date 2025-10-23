#!/data/data/com.termux/files/usr/bin/bash
# Function to display HELP section
show_help() {
  echo "Usage: bash <(curl -sSL https://gitlab.com/marmota/adb-wifi-enabler/-/raw/main/doit.sh) [options]"
  echo
  echo "This script automates enabling and connecting to ADB over Wi-Fi on this device (localhost)."
  echo "It first attempts a fast service discovery using zeroconf (mDNS)."
  echo "If that fails, it falls back to a slower, more comprehensive nmap port scan."
  echo "Once connected, it sets the connection port to 5555 and optionally activates Shizuku."
  echo
  echo "Options:"
  echo "  -d, --download     Download the latest version of this script to your home"
  echo "                     directory, set up Termux for Tasker integration, and print"
  echo "                     the script's full path. Useful for first-time setup with Tasker."
  echo "  -n, --no-shizuku   Skip the step of activating Shizuku."
  echo "  -h, --help         Display this help message and exit."
  echo
}
# Function to display INFO section (move this after all other function definitions)
show_info() {
  blue_echo "$asterisk_line"
  center_message "INFO"
  echo "If there is no connection, make sure you have paired using adb pair localhost.."
  echo "Screenshot and video of pairing in split screen mode:"
  echo "$asterisk_line"
  blue_echo "https://gitlab.com/marmota/adb-wifi-enabler/-/raw/main/adb_pair_Termux.png"
  echo "$asterisk_line"
  blue_echo "https://www.youtube.com/watch?v=OoVrljrPH5I"
  echo "$asterisk_line"
}
# Function to prompt for shell access
ask_for_shell() {
  echo "You can check 'top' in the shell."
  if read -t 5 -p "Enter shell? i - info, (Y/n/i): " response; then
    response=${response:-Y} # Default to Y if empty
    if [[ $response =~ ^[Yy]$ ]]; then
      # Try regular adb shell
      if adb shell; then
        echo "Exited ADB shell."
      else
        echo "'adb shell' failed, trying 'adb -s localhost:5555 shell'..."
        if ! adb -s localhost:5555 shell; then
          red_echo "Could not connect to ADB shell."
        fi
        echo "Exited ADB shell."
      fi
    elif [[ $response = "i" ]]; then
      echo -e "\n" # add newline after input
      show_info
      ask_for_shell # Ask again after showing info
    else
      echo "Exiting.."
      exit 0
    fi
  else
    echo -e "\nTime expired. Exiting.."
    exit 0
  fi
}
command_exists() {
  command -v "$1" >/dev/null 2>&1
}
# Function to check root access
check_root() {
  if su -c "echo 'Root access confirmed'" >/dev/null 2>&1; then
    return 0 # Root access
  fi
  return 1 # No root
}
# Function to get device IP
get_device_ip() {
  local ip=""
  # Try multiple methods to get IP
  if command_exists ip; then
    ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
  fi
  if [ -z "$ip" ]; then
    ip=$(ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | head -1)
  fi
  if [ -z "$ip" ]; then
    # Fallback method
    ip=$(ifconfig wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
  fi
  echo "$ip"
}
# Function to connect to ADB with retries
connect_with_retry() {
  local port=$1
  local retries=10
  for i in $(seq 1 $retries); do
    if adb connect "localhost:$port" 2>/dev/null | grep -q "connected"; then
      if ! adb devices | grep "$port" | grep -q "offline"; then
        return 0 # Connection successful
      fi
    fi
    sleep 1 # Delay to prevent hammering the connection attempt
  done
  return 1 # Failed to connect after retries
}
# Function to setup ADB TCP/IP using root
setup_adb_tcpip_root() {
  local port=${1:-5555}
  local ip
  blue_echo "Setting ADB TCP port to $port using root..."
  if su -c "setprop service.adb.tcp.port '$port' && stop adbd && start adbd" >/dev/null 2>&1; then
    green_echo "ADB daemon restarted in TCP mode via root."
  else
    red_echo "Failed to restart ADB daemon using root!"
    return 1
  fi
  sleep 2
  # We try to connect regardless of whether we can get the IP or not.
  # The IP is only for the user message if connection fails.
  blue_echo "Connecting to localhost:$port..."
  if connect_with_retry "$port"; then
    green_echo "Connected to localhost:$port"
    connected=true # Set the global connected flag
    return 0
  fi
  # If we are here, connection failed.
  red_echo "Direct connection to localhost failed, but TCP mode is enabled."
  ip=$(get_device_ip)
  if [ -n "$ip" ]; then
    green_echo "You can manually connect using: adb connect $ip:$port"
  else
    red_echo "Could not determine device IP address!"
    green_echo "You can manually connect using: adb connect <YOUR_IP>:$port"
  fi
  # The original script logic implies we should consider this a "success"
  # for the next stage, even if the connection isn't live yet.
  connected=true
  return 0
}
is_package_installed() {
  pkg_name=$1
  if dpkg -s "$pkg_name" &>/dev/null; then
    return 0
  else
    echo "Package '$pkg_name' is not installed."
    apt update && apt install "$pkg_name" -y
  fi
}
is_package_installed android-tools
is_package_installed nmap
is_package_installed ncurses-utils
# This command needs to be executed on the Android device, so we wrap it in single quotes.
shizuku_cmd='$(dirname $(pm path --user 0 moe.shizuku.privileged.api 2>&1 </dev/null | sed "s|.*:||" ))/lib/*/libshizuku.so'
# Helper function to run shizuku_cmd with fallback
shizuku_cmd_fallback() {
  if adb "$@" shell pm list packages | grep -q "moe.shizuku.privileged.api"; then
    green_echo "Shizuku is installed. Proceeding to activate."
    echo "Trying primary activation method (for Shizuku v13.6.0+)..."
    if adb "$@" shell "$shizuku_cmd"; then
      return 0
    else
      echo "Primary method failed. Trying fallback for older Shizuku versions..."
      adb "$@" shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh
    fi
  else
    red_echo "Shizuku (moe.shizuku.privileged.api) is not installed. Skipping activation."
    return 1
  fi
}
# Get terminal width
width=$(tput cols)
########### To echo an asterisk line ##############################
# Generate a line of asterisks matching the terminal width
asterisk_line=$(printf '%*s' "$width" | tr ' ' '*')
########### End To echo an asterisk line ##########################
######### Function to echo a centered message, padded with asterisks  #############
center_message() {
  local message="$1"
  local term_width=$width
  local message_length=${#message}
  local padding_length=$(((term_width - message_length) / 2 - 1))
  local padding=$(printf '%*s' "$padding_length" | tr ' ' '*')
  # Print the centered message
  echo -n "$padding $message $padding"
  # If the total length is odd, add one more asterisk at the end
  if [ $(((term_width - message_length) % 2)) -ne 0 ]; then
    echo -n "*"
  fi
  echo
}
######### Function to echo a centered message #############
center_echo() {
  message="$1"
  # Calculate padding for centering
  padding=$(((width - ${#message}) / 2))
  # Print spaces for left padding
  for ((i = 1; i <= $padding; i++)); do
    echo -n " "
  done
  # Print the message
  echo -n "$message"
  # Print spaces for right padding
  for ((i = 1; i <= $((width - padding - ${#message})); i++)); do
    echo -n " "
  done
}
######### Function to echo colored messages #############
red_echo() {
  echo -e "\e[31m$1\e[0m"
}
green_echo() {
  echo -e "\033[32m$1\033[0m"
}
blue_echo() {
  echo -e "\e[34m$1\e[0m"
}
######### End Function to echo colored messages #############
#############################################################
# Default values
ENABLE_SHIZUKU=true
# Parse command-line arguments
for arg in "$@"; do
  case $arg in
  -h | --help)
    show_help
    exit 0
    ;;
  -d | --download)
    echo "Downloading latest script version..."
    cd ~ || exit
    curl -L -o doit.sh https://gitlab.com/marmota/adb-wifi-enabler/-/raw/main/doit.sh
    chmod +x doit.sh
    echo "Script downloaded to ~/doit.sh"
    echo "You can use this path in Tasker:"
    realpath doit.sh
    echo
    blue_echo "--------------------------------------------------"
    center_message "Tasker Termux Command action Configuration"
    PROPERTIES_FILE=~/.termux/termux.properties
    PROPERTIES_DIR=~/.termux
    # Ensure the .termux directory exists
    mkdir -p "$PROPERTIES_DIR"
    # Check if the property is already correctly set
    if grep -q "^allow-external-apps = true$" "$PROPERTIES_FILE" 2>/dev/null; then
      was_true=true
    else
      was_true=false
    fi
    if [ "$was_true" = true ]; then
      green_echo "Notification: 'allow-external-apps' was already true."
    else
      if grep -q "^allow-external-apps" "$PROPERTIES_FILE" 2>/dev/null; then
        blue_echo "Notification: 'allow-external-apps' was false."
        sed -i '/^allow-external-apps/d' "$PROPERTIES_FILE"
      else
        blue_echo "Notification: 'allow-external-apps' was not set."
      fi
      echo "allow-external-apps = true" >>"$PROPERTIES_FILE"
      green_echo "Action: Set 'allow-external-apps = true' in $PROPERTIES_FILE."
      green_echo "Action: Reloading Termux settings..."
      termux-reload-settings
      blue_echo "This is required for the Tasker 'Termux' action to work."
      red_echo "Please grant Tasker permission to run commands in Termux environment."
    fi
    blue_echo "--------------------------------------------------"
    exit 0
    ;;
  -n | --no-shizuku)
    ENABLE_SHIZUKU=false
    shift # Remove the argument
    ;;
  esac
done
clear
echo "$asterisk_line"
center_echo "ADB Port Scanner"
# center_message "ADB Port Scanner"
echo "$asterisk_line"
echo "Uptime: $(uptime -p)"
# Try port 5555 first
echo "Trying default port 5555..."
if adb connect "localhost:5555" 2>/dev/null | grep -q "connected"; then
  if ! adb devices | grep "5555" | grep -q "offline"; then
    green_echo "Connection established on port 5555!"
    connected=true
  fi
fi
# Only continue if not connected
if ! [ "$connected" = true ]; then
  # --- START: New Root Check ---
  if check_root; then
    green_echo "Root access detected. Attempting root-based ADB activation."
    if setup_adb_tcpip_root; then
      green_echo "Root-based ADB activation successful."
    else
      red_echo "Root-based ADB activation failed. Falling back to standard method."
    fi
  else
    blue_echo "No root access detected. Proceeding with standard method."
    # --- Fallback to non-root methods ---
    # Try to launch Tasker intent to enable wireless debugging
    termux-open-url "tasker://assistantactions?task=adb_wifi_enabled"
    echo "Note: If Tasker is not installed, please enable wireless debugging manually in Developer Options."
    echo "Go to: Settings > System > Developer options > Wireless debugging."
    # --- START: New Zeroconf logic ---
    echo "Attempting discovery with the fast zeroconf (mDNS) method..."
    use_zeroconf=false
    # Check if python and zeroconf are installed
    if ! command -v python &>/dev/null || ! python -c "import zeroconf" &>/dev/null; then
      # If they are NOT installed, ask the user
      echo
      blue_echo "NOTE: The fast 'zeroconf' method requires Python (~50-100MB)."
      blue_echo "The 'nmap' fallback method is already installed and uses less space (~4MB)."
      echo
      read -p "Install Python & zeroconf for a faster search? (Y/n): " response
      response=${response:-Y} # Default to Yes
      if [[ $response =~ ^[Yy]$ ]]; then
        echo "Installing required packages for zeroconf..."
        is_package_installed python
        pip install zeroconf
        use_zeroconf=true
      else
        echo "Skipping Python installation. Proceeding with nmap only."
        use_zeroconf=false
      fi
    else
      # If they ARE already installed, just use them.
      use_zeroconf=true
    fi
    port=""
    if [ "$use_zeroconf" = true ]; then
      # Use python with zeroconf to find the port
      port=$(
        python - <<END
from zeroconf import Zeroconf, ServiceBrowser
import threading
import time
TYPE = "_adb-tls-connect._tcp.local."
class MyListener:
    def __init__(self, zeroconf, event):
        self.found_service = False
        self.zeroconf = zeroconf
        self.exit_event = event
        self.port = None
    def remove_service(self, zeroconf, type, name):
        pass
    def update_service(self, zeroconf, type, name):
        pass
    def add_service(self, zeroconf, type, name):
        if not self.found_service and name.startswith("adb-"):
            info = zeroconf.get_service_info(type, name)
            if info:
                self.port = info.port
                print(self.port)
                self.found_service = True
                self.exit_event.set() # Signal the main loop to exit
def main():
    zeroconf = Zeroconf()
    exit_event = threading.Event()
    listener = MyListener(zeroconf, exit_event)
    browser = ServiceBrowser(zeroconf, TYPE, listener)
    # Wait for the event to be set (service found) or timeout
    exit_event.wait(timeout=10) # 10 second timeout

    zeroconf.close()
if __name__ == '__main__':
    main()
END
      )
    fi
    if [ -n "$port" ]; then
      echo "Found service on port $port via zeroconf."
      echo "Trying to connect..."
      if connect_with_retry "$port"; then
        green_echo "Connection established!"
        connected=true
      fi
    fi
    if ! [ "$connected" = true ]; then
      if [ "$use_zeroconf" = true ] && [ -n "$port" ]; then
        echo "zeroconf connection to port $port failed. Falling back to nmap port scan..."
      elif [ "$use_zeroconf" = true ]; then
        echo "zeroconf discovery failed. Falling back to nmap port scan..."
      else
        echo "Proceeding with nmap port scan..."
      fi
      # --- START: Original nmap logic ---
      devices=$(adb devices | grep localhost | grep -v offline)
      if [ -z "$devices" ]; then
        START_TIME=$SECONDS
        echo "No devices connected via 'adb connect localhost...'"
        echo "Starting port scan.."
        # Use parallel port scanning with nmap
        ports=$(nmap -T4 localhost -p 33000-47000 --min-parallelism 10 | grep open | cut -d "/" -f1)
        if [ -z "$ports" ]; then
          red_echo "No open ports found"
          show_info
          exit 1
        fi
        mapfile -t port_array <<<"$ports"
        echo "Found ${#port_array[@]} open ports. Trying to connect.."
        found_connection=false
        for port in "${port_array[@]}"; do
          echo "Trying port $port..."
          if connect_with_retry "$port"; then
            green_echo "Connection established!"
            connected=true
            found_connection=true
            break
          fi
        done
        if [ "$found_connection" = false ]; then
          echo "No connected devices found after trying all ports."
        fi
        duration=$((SECONDS - START_TIME))
        time_word="seconds"
        if [ "$duration" -eq 1 ]; then
          time_word="second"
        fi
        echo "Script completed in $duration $time_word"
      else
        green_echo "Connection already established"
        connected=true
      fi
      # --- END: Original nmap logic ---
    fi
    # --- END: New Zeroconf logic ---
  fi
fi
# Continue with the rest of the script (TCP/IP setup and shell access)
if [ "$connected" = true ]; then
  current_port=$(adb devices | grep -w device | grep localhost | awk '{print $1}' | cut -d ":" -f2)
  if [ "$current_port" = "5555" ]; then
    echo "Already using port 5555"
    if adb devices | grep -w "localhost:5555" | grep -q "device"; then
      if [ "$ENABLE_SHIZUKU" = true ]; then
        shizuku_cmd_fallback -s localhost:5555
      else
        green_echo "Shizuku activation skipped by user."
      fi
    else
      red_echo "Port 5555 is not active. Skipping Shizuku command."
    fi
  else
    echo "Starting ADB TCP/IP mode on port 5555..."
    # Get all connected devices
    connected_devices=$(adb devices | grep -v "List" | grep "device$")
    device_count=$(adb devices | grep -v "List" | grep "device$" | wc -l)
    echo "Found $device_count connected devices:"
    if [ "$device_count" -gt 1 ]; then
      echo "Found multiple connected devices:"
      connected_to_5555=false
      while IFS= read -r device; do
        device_id=$(echo "$device" | awk '{print $1}')
        echo "Setting TCP/IP mode on device $device_id..."
        max_retries=10
        for i in $(seq 1 $max_retries); do
          adb -s "$device_id" tcpip 5555
          adb connect localhost:5555
          if adb devices | grep -w "localhost:5555" | grep -q "device"; then
            connected_to_5555=true
            break
          fi
          sleep 1
        done
        if [ "$connected_to_5555" = true ]; then
          break # exit while loop
        fi
      done <<<"$connected_devices"
      if [ "$connected_to_5555" = true ]; then
        if [ "$ENABLE_SHIZUKU" = true ]; then
          shizuku_cmd_fallback -s localhost:5555
        else
          green_echo "Shizuku activation skipped by user."
        fi
      else
        red_echo "Failed to connect to localhost:5555"
      fi
    elif [ "$device_count" -eq 1 ]; then
      device_id=$(echo "$connected_devices" | awk '{print $1}')
      echo "Setting TCP/IP mode on device $device_id..."
      max_retries=10
      connected_to_5555=false
      for i in $(seq 1 $max_retries); do
        adb -s "$device_id" tcpip 5555
        adb connect localhost:5555
        if adb devices | grep -w "localhost:5555" | grep -q "device"; then
          connected_to_5555=true
          break
        fi
        sleep 1
      done
      if [ "$connected_to_5555" = true ]; then
        if [ "$ENABLE_SHIZUKU" = true ]; then
          shizuku_cmd_fallback -s localhost:5555
        else
          green_echo "Shizuku activation skipped by user."
        fi
        adb -s localhost:5555 shell "settings put global adb_wifi_enabled 0"
        termux-open-url "tasker://assistantactions?task=adb_wifi_disabled"
      else
        red_echo "Failed to connect to localhost:5555"
      fi
    else
      echo "No connected devices found when trying to enable TCP/IP mode"
    fi
  fi
else
  echo "Connection not established!"
  show_info
fi
if [ "$connected" = true ]; then
  # Check USB debugging status at the end
  echo "$asterisk_line"
  center_message "Final USB Debugging Status"
  # Check on the primary connection target first
  if adb devices | grep -q "localhost:5555.*device"; then
    device_serial="localhost:5555"
  else
    # Fallback to the first available device if 5555 is not connected
    device_serial=$(adb devices | grep -w "device" | awk 'NR==1{print $1}')
  fi
  if [ -n "$device_serial" ]; then
    # The setting is 'adb_enabled', not 'usb_debugging_enabled'
    status=$(adb -s "$device_serial" shell settings get global adb_enabled)
    if [ "$status" = "1" ]; then
      green_echo "USB Debugging is currently ENABLED on $device_serial."
    elif [ "$status" = "0" ]; then
      red_echo "USB Debugging is currently DISABLED on $device_serial."
      green_echo "Enabling USB Debugging on $device_serial..."
      adb -s "$device_serial" shell settings put global adb_enabled 1
      # Verify the change
      new_status=$(adb -s "$device_serial" shell settings get global adb_enabled)
      if [ "$new_status" = "1" ]; then
        green_echo "USB Debugging has been successfully ENABLED."
      else
        red_echo "Failed to enable USB Debugging."
      fi
    else
      echo "Could not determine USB Debugging status on $device_serial."
    fi
  else
    red_echo "No connected device found to check status."
  fi
  echo "$asterisk_line"
  ask_for_shell
fi
