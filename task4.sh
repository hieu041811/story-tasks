#!/bin/bash
# A utility script for managing the Story project components
# Designed for educational purposes in classroom exercises

set -euo pipefail

# Define color codes for output
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"
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

# Function to install the latest Story
install_latest_story() {
    print_green "Installing the latest Story..."
    local story_url
    story_url=$(curl -s https://api.github.com/repos/piplabs/story/releases/latest | \
        grep 'browser_download_url' | grep 'story-linux-amd64' | head -n 1 | cut -d '"' -f 4)
    wget -qO story.tar.gz "${story_url}"
    tar -xzf story.tar.gz
    sudo cp story*/story /usr/local/bin/story
    rm -rf story* story.tar.gz
    story version
}

# Function to install the latest Geth-Story
install_latest_geth_story() {
    print_green "Installing the latest Geth-Story..."
    local geth_url
    geth_url=$(curl -s https://api.github.com/repos/piplabs/story-geth/releases/latest | \
        grep 'browser_download_url' | grep 'geth-linux-amd64' | head -n 1 | cut -d '"' -f 4)
    wget -qO geth.tar.gz "${geth_url}"
    tar -xzf geth.tar.gz
    sudo cp geth*/geth /usr/local/bin/story-geth
    rm -rf geth* geth.tar.gz
    story-geth version
}

# Function to check the current status of Story and Geth services
check_status() {
    print_green "Checking the current status of Story and Geth services..."
    systemctl status story --no-pager
    systemctl status story-geth --no-pager
}

# Function to check the latest block the process is working on
check_latest_block() {
    print_green "Checking the latest block the process is working on..."
    local latest_block
    latest_block=$(curl -s localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
    echo "Latest block height: $latest_block"
}

# Function to install snapshot for the process
install_snapshot() {
    print_green "Installing snapshot for the process..."
    local block
    block=$(curl -sS https://snapshots.mandragora.io/height.txt)
    echo "This snapshot at block $block is provided by Mandragora."

    # Stop services
    sudo systemctl stop story story-geth

    # Install necessary packages
    sudo apt-get update -y
    sudo apt-get install -y lz4 pv

    # Download snapshots
    wget -O geth_snapshot.lz4 https://snapshots.mandragora.io/geth_snapshot.lz4
    wget -O story_snapshot.lz4 https://snapshots.mandragora.io/story_snapshot.lz4

    # Backup validator state
    sudo cp "$HOME/.story/story/data/priv_validator_state.json" "$HOME/.story/priv_validator_state.json.backup"

    # Remove old data
    sudo rm -rf "$HOME/.story/geth/iliad/geth/chaindata"
    sudo rm -rf "$HOME/.story/story/data"

    # Extract snapshots
    lz4 -c -d geth_snapshot.lz4 | tar -x -C "$HOME/.story/geth/iliad/geth"
    lz4 -c -d story_snapshot.lz4 | tar -x -C "$HOME/.story/story"

    # Clean up snapshot files
    rm -v geth_snapshot.lz4 story_snapshot.lz4

    # Restore validator state
    sudo cp "$HOME/.story/priv_validator_state.json.backup" "$HOME/.story/story/data/priv_validator_state.json"

    # Start services
    sudo systemctl start story-geth
    sudo systemctl start story
}

# Function to refresh the process if there are any errors
refresh_process() {
    print_green "Refreshing the process..."
    sudo systemctl restart story
    sudo systemctl restart story-geth
}

# Function to get user's keys
get_user_keys() {
    print_green "Retrieving user's keys..."
    print_line
    # Export keys (Note: Be cautious with private keys)
    story validator export --export-evm-key

    # Display keys (Security Warning)
    echo "Private key (stored in private_key.txt):"
    cat "$HOME/.story/story/config/private_key.txt"
    echo "Validator address:"
    jq -r '.address' "$HOME/.story/story/config/priv_validator_key.json"
    print_red "Warning: Exposing private keys can compromise security. Handle with care."
}

# Function to start Story services
start_story() {
    print_green "Starting Story services..."
    sudo systemctl start story
    sudo systemctl start story-geth
}

# Function to stop Story services
stop_story() {
    print_green "Stopping Story services..."
    sudo systemctl stop story
    sudo systemctl stop story-geth
}

# Function to restart Story services
restart_story() {
    print_green "Restarting Story services..."
    sudo systemctl restart story
    sudo systemctl restart story-geth
}

# Function to get the latest block from the testnet server
get_latest_block_from_testnet() {
    print_green "Getting the latest block from the testnet server..."
    local latest_block
    latest_block=$(curl -s https://story-testnet-rpc.polkachu.com/status | jq -r '.result.sync_info.latest_block_height')
    echo "Latest block height on testnet server: $latest_block"
}

# Function to install Grafana
install_grafana() {
    print_green "Installing Grafana..."
    sudo apt-get update -y
    sudo apt-get install -y apt-transport-https software-properties-common wget
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    echo "deb https://packages.grafana.com/enterprise/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
    sudo apt-get update -y
    sudo apt-get install -y grafana-enterprise
    sudo systemctl daemon-reload
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server
    print_green "Grafana installed and started."
}

# Function to stop Grafana
stop_grafana() {
    print_green "Stopping Grafana..."
    sudo systemctl stop grafana-server
    print_green "Grafana stopped."
}

# Function to uninstall Grafana
uninstall_grafana() {
    print_green "Uninstalling Grafana..."
    sudo systemctl stop grafana-server
    sudo systemctl disable grafana-server
    sudo apt-get remove --purge -y grafana-enterprise
    sudo rm -rf /etc/grafana /var/lib/grafana
    print_green "Grafana uninstalled."
}

# Function to display the main menu
main_menu() {
    echo -e "${COLOR_CYAN}Story Utility Tool${COLOR_RESET}"
    print_line
    echo "1. Install latest Story"
    echo "2. Install latest Geth-Story"
    echo "3. Check current status of Story and Geth"
    echo "4. Check the latest block the process is working on"
    echo "5. Install snapshot for the process"
    echo "6. Refresh process if there are any errors"
    echo "7. Get user's keys (public key, private key, public address)"
    echo "8. Start Story services"
    echo "9. Stop Story services"
    echo "10. Restart Story services"
    echo "11. Get the latest block from testnet server"
    echo "12. Install Grafana"
    echo "13. Stop Grafana"
    echo "14. Uninstall Grafana"
    echo "q. Quit"
    print_line
}

# Main script execution
main() {
    while true; do
        main_menu
        read -rp "Enter your choice: " choice
        case "$choice" in
            1) install_latest_story ;;
            2) install_latest_geth_story ;;
            3) check_status ;;
            4) check_latest_block ;;
            5) install_snapshot ;;
            6) refresh_process ;;
            7) get_user_keys ;;
            8) start_story ;;
            9) stop_story ;;
            10) restart_story ;;
            11) get_latest_block_from_testnet ;;
            12) install_grafana ;;
            13) stop_grafana ;;
            14) uninstall_grafana ;;
            q|Q) exit 0 ;;
            *) print_red "Invalid choice, please try again." ;;
        esac
    done
}

# Execute the main function
main