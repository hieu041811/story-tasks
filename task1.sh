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
    
    # Detect system architecture
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        ARCH="amd64"
    elif [[ "$ARCH" == "arm"* || "$ARCH" == "aarch64" ]]; then
        ARCH="arm64"
    else
        echo "Unsupported architecture: $ARCH"
        return 1
    fi
    
    # Fetch the latest release data
    RELEASE_DATA=$(curl -s https://api.github.com/repos/piplabs/story/releases/latest)
    
    # Extract the URL for the story binary based on architecture
    STORY_URL=$(echo "$RELEASE_DATA" | grep 'body' | grep -Eo "https?://[^ ]+story-linux-${ARCH}[^ ]+" | sed 's/......$//')
    
    if [ -z "$STORY_URL" ]; then
        echo "Failed to fetch Story URL. Exiting."
        return 1
    fi
    
    echo "Fetched Story URL: $STORY_URL"
    wget -qO story-linux-$ARCH.tar.gz "$STORY_URL"
    
    if [ ! -f story-linux-$ARCH.tar.gz ]; then
        echo "Failed to download Story. Exiting."
        return 1
    fi
    
    echo "Configuring Story..."
    
    # Check if the file is a tar.gz archive and extract it
    if file story-linux-$ARCH.tar.gz | grep -q 'gzip compressed data'; then
        tar -xzf story-linux-$ARCH.tar.gz
        rm story-linux-$ARCH.tar.gz
    else
        echo "Downloaded file is not a valid tar.gz archive. Exiting."
        return 1
    fi
    
    # Verify if the extracted folder exists
    EXTRACTED_FOLDER=$(ls -d story-linux-$ARCH-* 2>/dev/null || true)
    if [ -z "$EXTRACTED_FOLDER" ]; then
        echo "Extracted folder not found. Exiting."
        return 1
    fi
    
    [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
    if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
        echo 'export PATH=$PATH:$HOME/go/bin' >> $HOME/.bash_profile
    fi
    
    # Move the contents of the extracted folder to $HOME/go/bin
    sudo rm -rf $HOME/go/bin/story
    sudo mv "$EXTRACTED_FOLDER"/* $HOME/go/bin/story
    rm -rf "$EXTRACTED_FOLDER"
    source $HOME/.bash_profile
    
    if ! $HOME/go/bin/story version; then
        echo "Failed to execute story. Please check permissions."
        return 1
    fi
    story version
}

# Function to install Geth
install_geth() {
    print_header "Installing Geth"
    GETH_URL=$(curl -s https://api.github.com/repos/piplabs/story-geth/releases/latest | grep 'browser_download_url' | grep 'geth-linux-amd64' | head -n 1 | cut -d '"' -f 4)
    
    if [ -z "$GETH_URL" ]; then
        echo "Failed to fetch Geth URL. Exiting."
        return 1
    fi
    
    echo "Fetched Geth URL: $GETH_URL"
    wget -qO geth-linux-amd64 "$GETH_URL"
    
    if [ ! -f geth-linux-amd64 ]; then
        echo "Failed to download Geth. Exiting."
        return 1
    fi
    
    echo "Configuring Story Geth..."
    
    chmod +x geth-linux-amd64
    
    [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
    if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
        echo 'export PATH=$PATH:$HOME/go/bin' >> $HOME/.bash_profile
    fi
    
    rm -f $HOME/go/bin/story-geth
    mv geth-linux-amd64 $HOME/go/bin/story-geth
    chmod +x $HOME/go/bin/story-geth
    source $HOME/.bash_profile
    
    if ! $HOME/go/bin/story-geth version; then
        echo "Failed to execute story-geth. Please check permissions."
        return 1
    fi
}

# Function to install Story Consensus
install_story_consensus() {
    print_header "Installing Story Consensus"
    
    # Detect system architecture
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        ARCH="amd64"
    elif [[ "$ARCH" == "arm"* || "$ARCH" == "aarch64" ]]; then
        ARCH="arm64"
    else
        echo "Unsupported architecture: $ARCH"
        return 1
    fi
    
    # Fetch the latest release data
    RELEASE_DATA=$(curl -s https://api.github.com/repos/piplabs/story/releases/latest)
    
    # Extract the URL for the story binary based on architecture
    STORY_URL=$(echo "$RELEASE_DATA" | grep 'body' | grep -Eo "https?://[^ ]+story-linux-${ARCH}[^ ]+" | sed 's/......$//')
    
    if [ -z "$STORY_URL" ]; then
        echo "Failed to fetch Story URL. Exiting."
        return 1
    fi
    
    echo "Fetched Story URL: $STORY_URL"
    wget -qO story-linux-$ARCH.tar.gz "$STORY_URL"
    
    if [ ! -f story-linux-$ARCH.tar.gz ]; then
        echo "Failed to download Story. Exiting."
        return 1
    fi
    
    echo "Configuring Story..."
    
    # Check if the file is a tar.gz archive and extract it
    if file story-linux-$ARCH.tar.gz | grep -q 'gzip compressed data'; then
        tar -xzf story-linux-$ARCH.tar.gz
        rm story-linux-$ARCH.tar.gz
    else
        echo "Downloaded file is not a valid tar.gz archive. Exiting."
        return 1
    fi
    
    # Verify if the extracted folder exists
    EXTRACTED_FOLDER=$(ls -d story-linux-$ARCH-* 2>/dev/null || true)
    if [ -z "$EXTRACTED_FOLDER" ]; then
        echo "Extracted folder not found. Exiting."
        return 1
    fi
    
    [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
    if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
        echo 'export PATH=$PATH:$HOME/go/bin' >> $HOME/.bash_profile
    fi
    
    # Move the contents of the extracted folder to $HOME/go/bin
    sudo rm -rf $HOME/go/bin/story
    sudo mv "$EXTRACTED_FOLDER"/* $HOME/go/bin/story
    rm -rf "$EXTRACTED_FOLDER"
    source $HOME/.bash_profile
    
    if ! $HOME/go/bin/story version; then
        echo "Failed to execute story. Please check permissions."
        return 1
    fi
    story version
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
