#!/bin/bash
# A script to install snapshots for the Story project with enhanced logging and structure
# Designed for educational purposes in classroom exercises

set -euo pipefail

# Define color codes for output
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_RESET="\033[0m"

# Function to print messages in green
print_green() {
    echo -e "${COLOR_GREEN}$1${COLOR_RESET}"
}

# Function to print messages in red
print_red() {
    echo -e "${COLOR_RED}$1${COLOR_RESET}"
}

# Function to print a separator line
print_line() {
    echo "----------------------------------------"
}

# Function to update and install necessary packages
install_dependencies() {
    print_green "1. Installing dependencies..."
    sleep 1
    sudo apt-get update -y
    sudo apt-get install -y curl git wget htop tmux jq make lz4 unzip bc
}

# Define global variables
declare -r TYPE="testnet"
declare -r PROJECT="story"
declare -r ROOT_URL="server-3.itrocket.net"
declare -r STORY_PATH="$HOME/.story/story"
declare -r GETH_PATH="$HOME/.story/geth/iliad/geth"
declare -r PARENT_RPC="https://story-testnet-rpc.itrocket.net"
declare -r MAX_ATTEMPTS=3
declare -r FILE_SERVERS=(
    "https://server-3.itrocket.net/testnet/story/.current_state.json"
    "https://server-1.itrocket.net/testnet/story/.current_state.json"
    "https://server-5.itrocket.net/testnet/story/.current_state.json"
)
declare -a SNAPSHOTS=()

# Function to fetch snapshot data from a server
fetch_snapshot_data() {
    local url="$1"
    local attempt=0
    local data=""

    while (( attempt < MAX_ATTEMPTS )); do
        data=$(curl -s --max-time 5 "$url" || true)
        if [[ -n "$data" ]]; then
            echo "$data"
            return 0
        else
            ((attempt++))
            sleep 1
        fi
    done

    return 1
}

# Function to parse and store snapshot information
collect_snapshots() {
    for file_server in "${FILE_SERVERS[@]}"; do
        data=$(fetch_snapshot_data "$file_server") || continue
        if [[ -n "$data" ]]; then
            local server_url="${file_server%/*/*/*/.current_state.json}"
            local server_number=$(echo "$server_url" | grep -oP 'server-\K[0-9]+')
            local snapshot_name=$(echo "$data" | jq -r '.snapshot_name')
            local geth_name=$(echo "$data" | jq -r '.snapshot_geth_name')
            local snapshot_height=$(echo "$data" | jq -r '.snapshot_height')
            local snapshot_size=$(echo "$data" | jq -r '.snapshot_size')
            local geth_size=$(echo "$data" | jq -r '.geth_snapshot_size')
            local total_size_gb=$(echo "scale=2; ($snapshot_size + $geth_size) / (1024^3)" | bc)
            local snapshot_age=$(echo "$data" | jq -r '.snapshot_age')
            local estimated_time="N/A"  # Placeholder for estimated time calculation

            SNAPSHOTS+=("$server_number|$snapshot_name|$snapshot_height|$snapshot_age|$total_size_gb|$snapshot_size|$geth_size|$estimated_time|$server_url|$snapshot_name|$geth_name")
        fi
    done
}

# Function to display available snapshots
display_snapshots() {
    print_green "Available snapshots:"
    print_line
    for i in "${!SNAPSHOTS[@]}"; do
        IFS='|' read -r server_number snapshot_type snapshot_height snapshot_age total_size_gb snapshot_size geth_size estimated_time server_url snapshot_name geth_name <<< "${SNAPSHOTS[$i]}"
        echo "[$i] Server $server_number: $snapshot_type | Height: $snapshot_height | Age: $snapshot_age | Size: ${total_size_gb}GB | Est. Time: $estimated_time"
    done
}

# Function to install the selected snapshot
install_snapshot() {
    local snapshot_name="$1"
    local geth_name="$2"
    local server_url="$3"

    print_green "Installing snapshot from $server_url:"
    print_line
    print_green "Stopping 'story' and 'story-geth' services..."
    sleep 1
    sudo systemctl stop story story-geth

    print_green "Backing up 'priv_validator_state.json'..."
    sleep 1
    cp "$STORY_PATH/data/priv_validator_state.json" "$STORY_PATH/priv_validator_state.json.backup"

    print_green "Removing old data and unpacking Story snapshot..."
    sleep 1
    rm -rf "$STORY_PATH/data"
    curl "$server_url/${TYPE}/${PROJECT}/$snapshot_name" | lz4 -dc - | tar -xf - -C "$STORY_PATH"

    print_green "Restoring 'priv_validator_state.json'..."
    sleep 1
    mv "$STORY_PATH/priv_validator_state.json.backup" "$STORY_PATH/data/priv_validator_state.json"

    print_green "Deleting Geth data and unpacking Geth snapshot..."
    sleep 1
    rm -rf "$GETH_PATH/chaindata"
    curl "$server_url/${TYPE}/${PROJECT}/$geth_name" | lz4 -dc - | tar -xf - -C "$GETH_PATH"

    print_green "Starting 'story' and 'story-geth' services..."
    sleep 1
    sudo systemctl restart story story-geth

    print_green "Snapshot installation complete."
}

# Main script execution starts here
main() {
    install_dependencies
    collect_snapshots

    if [[ ${#SNAPSHOTS[@]} -eq 0 ]]; then
        print_red "No snapshots available to install."
        exit 1
    fi

    display_snapshots

    # Prompt user to select a snapshot
    read -rp "Enter the number of the snapshot you want to install: " choice

    # Validate user choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 0 && choice < ${#SNAPSHOTS[@]} )); then
        IFS='|' read -r server_number snapshot_type snapshot_height snapshot_age total_size_gb snapshot_size geth_size estimated_time server_url snapshot_name geth_name <<< "${SNAPSHOTS[$choice]}"
        install_snapshot "$snapshot_name" "$geth_name" "$server_url"
    else
        print_red "Invalid choice. Exiting."
        exit 1
    fi
}

# Execute the main function
main
