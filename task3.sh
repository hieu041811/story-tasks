#!/bin/bash
# A script to install and configure Prometheus and Grafana for monitoring the 'story' node
# Designed for educational purposes in classroom exercises

set -euo pipefail

# Define color codes for output
COLOR_GREEN="\e[32m"
COLOR_PINK="\e[35m"
COLOR_RESET="\e[0m"

# Function to print messages in green
print_green() {
    echo -e "${COLOR_GREEN}$1${COLOR_RESET}"
}

# Function to print messages in pink
print_pink() {
    echo -e "${COLOR_PINK}$1${COLOR_RESET}"
}

# Function to check the status of a service
check_service_status() {
    local service_name="$1"
    if systemctl is-active --quiet "$service_name"; then
        echo "$service_name is running."
    else
        echo "$service_name is not running."
    fi
}

# Function to ensure the script is run as root
ensure_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
}

# Function to update and upgrade the system
update_system() {
    print_green "************* Update and upgrade the system *************"
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}

# Function to install necessary dependencies
install_dependencies() {
    print_green "************* Install necessary dependencies *************"
    apt-get install -y curl tar wget gawk netcat jq apt-transport-https software-properties-common
}

# Function to get node status and extract variables
get_node_status() {
    print_green "************* Retrieve status of node *************"
    local config_file="$HOME/.story/story/config/config.toml"
    local port
    port=$(awk '/\[rpc\]/ {f=1} f && /laddr/ {match($0, /127\.0\.0\.1:([0-9]+)/, arr); print arr[1]; f=0}' "$config_file")
    local json_data
    json_data=$(curl -s "http://localhost:$port/status")
    story_address=$(echo "$json_data" | jq -r '.result.validator_info.address')
    network=$(echo "$json_data" | jq -r '.result.node_info.network')
}

# Function to create necessary directories
create_directories() {
    print_green "************* Create necessary directories *************"
    local directories=(
        "/var/lib/prometheus"
        "/etc/prometheus/rules"
        "/etc/prometheus/rules.d"
        "/etc/prometheus/files_sd"
    )
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ] && [ "$(ls -A "$dir")" ]; then
            echo "$dir already exists and is not empty. Skipping..."
        else
            mkdir -p "$dir"
            echo "Created directory: $dir"
        fi
    done
}

# Function to download and install Prometheus
install_prometheus() {
    print_green "************* Download and install Prometheus *************"
    cd "$HOME"
    rm -rf prometheus*
    wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
    tar xvf prometheus-2.45.0.linux-amd64.tar.gz
    rm prometheus-2.45.0.linux-amd64.tar.gz
    cd prometheus-2.45.0.linux-amd64

    # Move consoles and console_libraries if they don't already exist
    [ ! -d "/etc/prometheus/consoles" ] && mv consoles /etc/prometheus/
    [ ! -d "/etc/prometheus/console_libraries" ] && mv console_libraries /etc/prometheus/

    # Move binaries to /usr/local/bin
    mv prometheus promtool /usr/local/bin/
}

# Function to configure Prometheus
configure_prometheus() {
    print_green "************* Configure Prometheus *************"
    local prometheus_config="/etc/prometheus/prometheus.yml"
    [ -f "$prometheus_config" ] && rm "$prometheus_config"

    cat <<EOF > "$prometheus_config"
global:
  scrape_interval: 15s
  evaluation_interval: 15s
alerting:
  alertmanagers:
    - static_configs:
        - targets: []
rule_files: []
scrape_configs:
  - job_name: "prometheus"
    metrics_path: /metrics
    static_configs:
      - targets: ["localhost:9345"]
  - job_name: "story"
    scrape_interval: 5s
    metrics_path: /
    static_configs:
      - targets: ['localhost:26660']
EOF
}

# Function to create Prometheus service
create_prometheus_service() {
    print_green "************* Create Prometheus service *************"
    cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.listen-address=0.0.0.0:9344
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus

    # Check Prometheus service status
    check_service_status "prometheus"
}

# Function to install Grafana
install_grafana() {
    print_green "************* Install Grafana *************"
    wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
    echo "deb https://packages.grafana.com/enterprise/deb stable main" > /etc/apt/sources.list.d/grafana.list
    apt-get update -y
    apt-get install -y grafana-enterprise
    systemctl daemon-reload
    systemctl enable grafana-server
    systemctl start grafana-server

    # Check Grafana service status
    check_service_status "grafana-server"
}

# Function to configure Grafana
configure_grafana() {
    print_green "************* Configure Grafana *************"
    local grafana_config_file="/etc/grafana/grafana.ini"
    local new_port="9346"

    if [ -f "$grafana_config_file" ]; then
        sed -i "s/^;http_port = .*/http_port = $new_port/" "$grafana_config_file"
        systemctl restart grafana-server
        check_service_status "grafana-server"
    else
        echo "Grafana configuration file not found: $grafana_config_file"
        exit 1
    fi
}

# Function to install Prometheus Node Exporter
install_node_exporter() {
    print_green "************* Install and start Prometheus Node Exporter *************"
    apt-get install -y prometheus-node-exporter

    # Remove existing service file if it exists
    local service_file="/etc/systemd/system/prometheus-node-exporter.service"
    if [ -f "$service_file" ]; then
        rm "$service_file"
        echo "Removed existing service file: $service_file"
    fi

    # Create new service file
    cat <<EOF > "$service_file"
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/prometheus-node-exporter --web.listen-address=0.0.0.0:9345
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable prometheus-node-exporter
    systemctl start prometheus-node-exporter

    # Check Node Exporter service status
    check_service_status "prometheus-node-exporter"
}

# Function to modify story configuration to enable Prometheus
enable_prometheus_in_story() {
    print_green "************* Enable Prometheus in Story configuration *************"
    local config_file="$HOME/.story/story/config/config.toml"
    local search_text="prometheus = false"
    local replacement_text="prometheus = true"

    if grep -qFx "$replacement_text" "$config_file"; then
        echo "Prometheus is already enabled in Story configuration."
    else
        sed -i "s/$search_text/$replacement_text/" "$config_file"
        echo "Prometheus enabled in Story configuration."
        systemctl restart story
        check_service_status "story"
    fi
}

# Function to configure Grafana with Prometheus data source and dashboard
configure_grafana_dashboard() {
    print_green "************* Configure Grafana Dashboard *************"
    local grafana_host="http://localhost:9346"
    local admin_user="admin"
    local admin_password="admin"
    local prometheus_url="http://localhost:9344"
    local dashboard_url="https://raw.githubusercontent.com/encipher88/story-grafana/main/story.json"

    # Get the real IP address of the server
    real_ip=$(hostname -I | awk '{print $1}')

    # Download and modify the dashboard JSON
    local dashboard_file="$HOME/story.json"
    curl -s "$dashboard_url" -o "$dashboard_file"
    sed -i "s/FCB1BF9FBACE6819137DFC999255175B7CA23C5D/$story_address/g" "$dashboard_file"

    # Configure Prometheus data source in Grafana
    curl -s -X POST "$grafana_host/api/datasources" \
        -H "Content-Type: application/json" \
        -u "$admin_user:$admin_password" \
        -d '{
              "name": "Prometheus",
              "type": "prometheus",
              "access": "proxy",
              "url": "'"$prometheus_url"'",
              "basicAuth": false,
              "isDefault": true
            }' > /dev/null

    # Import the dashboard into Grafana
    curl -s -X POST "$grafana_host/api/dashboards/db" \
        -H "Content-Type: application/json" \
        -u "$admin_user:$admin_password" \
        -d '{
              "dashboard": '"$(cat "$dashboard_file")"',
              "overwrite": true,
              "folderId": 0
            }' > /dev/null

    # Output access details
    print_green "************* Dashboard imported successfully *************"
    print_pink "Grafana is accessible at: http://$real_ip:9346/d/UJyurCTWz/"
    print_pink "Login credentials:"
    echo -e "${COLOR_PINK}---------Username:    admin${COLOR_RESET}"
    echo -e "${COLOR_PINK}---------Password:    admin${COLOR_RESET}"
    echo -e "${COLOR_PINK}---------Validator:   $story_address${COLOR_RESET}"
    echo -e "${COLOR_PINK}---------Chain_ID:    $network${COLOR_RESET}"
}

# Main function to orchestrate the setup
main() {
    ensure_root
    update_system
    install_dependencies
    get_node_status
    create_directories
    install_prometheus
    configure_prometheus
    create_prometheus_service
    install_grafana
    configure_grafana
    install_node_exporter
    enable_prometheus_in_story

    # Restart services to apply changes
    systemctl restart prometheus
    systemctl restart prometheus-node-exporter
    systemctl restart grafana-server

    # Check services status
    sleep 3
    check_service_status "prometheus"
    check_service_status "prometheus-node-exporter"
    check_service_status "grafana-server"

    configure_grafana_dashboard

    print_green "************* Installation Complete *************"
}

# Execute the main function
main
