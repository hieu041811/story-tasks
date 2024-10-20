#!/bin/bash
# A script to install various components with enhanced logging and structure
# For educational purposes in class exercises

set -euo pipefail

# Define color codes for output
COLOR_GREEN="\e[32m"
COLOR_CYAN="\e[36m"
COLOR_RESET="\e[0m"

# Function to print section headers with green color
print_header() {
    echo -e "${COLOR_GREEN}************* $1 *************${COLOR_RESET}"
}

# Function to display the main menu
main_menu() {
    echo -e "${COLOR_CYAN}Main Menu${COLOR_RESET}"
    echo "1. Install Story"
    echo "2. Install Geth"
    echo "3. Install Story Consensus"
    echo "4. Automatic Update Story"
    echo "5. View Latest Story and Geth Versions"
    echo "q. Quit"
}

# Function to install the Go programming language
install_go() {
    print_header "Installing Go"
    GO_VERSION="1.23.2"
    GO_ARCHIVE="go${GO_VERSION}.linux-amd64.tar.gz"
    wget "https://go.dev/dl/${GO_ARCHIVE}"
    sudo tar -C /usr/local -xzf "${GO_ARCHIVE}"
    rm -f "${GO_ARCHIVE}"

    # Update environment variables
    {
        echo 'export PATH=$PATH:/usr/local/go/bin'
        echo 'export GOPATH=$HOME/go'
        echo 'export PATH=$PATH:$GOPATH/bin'
    } >> ~/.profile
    source ~/.profile
    go version
}

# Function to install Story
install_story() {
    print_header "Installing Story"
    STORY_URL=$(curl -s https://api.github.com/repos/piplabs/story/releases/latest | \
        grep 'browser_download_url' | grep 'story-linux-amd64' | head -n 1 | cut -d '"' -f 4)
    wget -qO story.tar.gz "${STORY_URL}"
    echo "Extracting and configuring Story..."
    tar xf story.tar.gz

    # Remove the existing symbolic link if it exists
    if [ -L /usr/local/bin/story ]; then
        sudo rm /usr/local/bin/story
    fi

    sudo cp -f story*/story /usr/local/bin/
    rm -rf story*/ story.tar.gz
}

# Function to install Geth
install_geth() {
    print_header "Installing Geth"
    GETH_URL=$(curl -s https://api.github.com/repos/piplabs/story-geth/releases/latest | \
        grep 'browser_download_url' | grep 'geth-linux-amd64' | head -n 1 | cut -d '"' -f 4)
    wget -qO geth.tar.gz "${GETH_URL}"
    echo "Extracting and configuring Geth..."
    tar xf geth.tar.gz
    sudo cp geth*/geth /usr/local/bin/
    rm -rf geth*/ geth.tar.gz
}

# Function to install Story Consensus
install_story_consensus() {
    print_header "Installing Story Consensus"
    install_story
}

# Function for automatic Story updates
auto_update_story() {
    print_header "Automatic Update Story"
    install_go
    cd "$HOME"
    rm -rf story
    git clone https://github.com/piplabs/story
    cd story
    LATEST_BRANCH=$(git branch -r | grep -v 'HEAD' | tail -n 1 | awk -F'/' '{print $2}')
    git checkout "${LATEST_BRANCH}"
    go build -o story ./client
    OLD_BIN_PATH=$(which story || true)
    HOME_PATH="$HOME"
    RPC_PORT=$(grep -m 1 -oP '^laddr = "\K[^"]+' "$HOME/.story/story/config/config.toml" | cut -d ':' -f 3)
    [[ -z "${RPC_PORT}" ]] && RPC_PORT=$(grep -oP 'node = "tcp://[^:]+:\K\d+' "$HOME/.story/story/config/client.toml")
    tmux new -s story-upgrade "sudo bash -c 'curl -s https://raw.githubusercontent.com/itrocket-team/testnet_guides/main/utils/autoupgrade/upgrade.sh | \
        bash -s -- -u \"1325860\" -b story -n \"$HOME/story/story\" -o \"$OLD_BIN_PATH\" -h \"$HOME_PATH\" -p \"undefined\" -r \"$RPC_PORT\"'"
}

# Function to display the latest versions of Story and Geth
show_latest_versions() {
    print_header "Latest Versions"
    LATEST_STORY_VERSION=$(curl -s https://api.github.com/repos/piplabs/story/releases/latest | \
        grep 'tag_name' | head -n 1 | cut -d '"' -f 4)
    LATEST_GETH_VERSION=$(curl -s https://api.github.com/repos/piplabs/story-geth/releases/latest | \
        grep 'tag_name' | head -n 1 | cut -d '"' -f 4)
    echo "Latest Story version: ${LATEST_STORY_VERSION}"
    echo "Latest Geth version: ${LATEST_GETH_VERSION}"
}

# Main script loop
while true; do
    main_menu
    read -rp "Enter the number of the option you want: " CHOICE
    case "${CHOICE}" in
        1) install_story ;;
        2) install_geth ;;
        3) install_story_consensus ;;
        4) auto_update_story ;;
        5) show_latest_versions ;;
        q|Q) exit 0 ;;
        *) echo "Invalid option: ${CHOICE}" ;;
    esac
done
