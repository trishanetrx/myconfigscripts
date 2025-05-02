#!/bin/bash

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Unsupported platform."
    exit 1
fi

# Community Edition version mappings
declare -A VERSION_URLS
VERSION_URLS["10.4.1"]="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.4.1.88267.zip"
VERSION_URLS["10.7.0"]="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.7.0.96327.zip"
VERSION_URLS["24.12.0"]="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-24.12.0.90901.zip"
VERSION_URLS["25.4.0"]="https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.4.0.105899.zip"
VERSIONS=("10.4.1" "10.7.0" "24.12.0" "25.4.0")

INSTALL_DIR="/opt/sonarqube"
BACKUP_DIR="/opt/sonarqube_backup_$(date +%F_%T)"

install_dependencies() {
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt update
        sudo apt install -y openjdk-17-jdk unzip wget nginx net-tools
        if ! command -v psql > /dev/null; then
            wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -
            echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
            sudo apt update
            sudo apt install -y postgresql-15
        fi
    elif [[ "$OS" == "rhel" || "$OS" == "centos" ]]; then
        sudo yum install -y java-17-openjdk wget unzip nginx net-tools
        sudo yum install -y https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
        sudo yum install -y postgresql15 postgresql15-server
        sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
        sudo systemctl enable postgresql-15
        sudo systemctl start postgresql-15
    else
        echo "❌ Unsupported OS: $OS"
        exit 1
    fi
}

create_postgres_user_and_db() {
    sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='sonarqube'" | grep -q 1 || sudo -u postgres psql -c "CREATE USER sonarqube WITH PASSWORD 'yourpasswordhere';"
    sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw sonarqube || sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonarqube;"
}

configure_limits() {
    sudo bash -c 'echo "vm.max_map_count=524288" >> /etc/sysctl.conf'
    sudo bash -c 'echo "fs.file-max=131072" >> /etc/sysctl.conf'
    sudo sysctl --system
    sudo bash -c 'echo "sonarqube - nofile 131072" > /etc/security/limits.d/99-sonarqube.conf'
    sudo bash -c 'echo "sonarqube - nproc 8192" >> /etc/security/limits.d/99-sonarqube.conf'
}

create_sonar_user() {
    id -u sonarqube &>/dev/null || sudo useradd -b /opt -s /bin/bash sonarqube
}

install_nginx_proxy() {
    CONFIG_CONTENT=$(cat <<EOF
server {
    listen 80;
    server_name test1.negombotech.com;

    access_log /var/log/nginx/sonar.access.log;
    error_log /var/log/nginx/sonar.error.log;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
    }
}
EOF
)

    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        echo "$CONFIG_CONTENT" | sudo tee /etc/nginx/sites-available/sonarqube
        sudo ln -sf /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
        sudo rm -f /etc/nginx/sites-enabled/default
    else
        echo "$CONFIG_CONTENT" | sudo tee /etc/nginx/conf.d/sonarqube.conf
    fi

    sudo nginx -t && sudo systemctl restart nginx
}

install_sonarqube() {
    VERSION=$1
    FILE_URL=${VERSION_URLS[$VERSION]}
    FILE_NAME=$(basename "$FILE_URL")

    wget -O "$FILE_NAME" "$FILE_URL"
    unzip -o "$FILE_NAME"
    EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "sonarqube-*" | sort | tail -n 1)
    [ -z "$EXTRACTED_DIR" ] && echo "❌ Could not extract SonarQube $VERSION" && exit 1

    sudo mv "$EXTRACTED_DIR" "$INSTALL_DIR"
    sudo chown -R sonarqube:sonarqube "$INSTALL_DIR"

    sudo bash -c "cat <<EOF > $INSTALL_DIR/conf/sonar.properties
sonar.jdbc.username=sonarqube
sonar.jdbc.password=yourpasswordhere
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
sonar.web.host=127.0.0.1
sonar.web.port=9000
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m
sonar.web.javaAdditionalOpts=-server
sonar.log.level=INFO
sonar.path.logs=logs
EOF"

    sudo bash -c "cat <<EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=$INSTALL_DIR/bin/linux-x86-64/sonar.sh start
ExecStop=$INSTALL_DIR/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF"

    sudo systemctl daemon-reload
    sudo systemctl enable sonarqube
    sudo systemctl restart sonarqube
}

get_schema_version() {
    sudo -u postgres psql -d sonarqube -tAc "SELECT value FROM metadata WHERE name = 'schema_version';" 2>/dev/null | tr -d ' '
}

safe_upgrade_path() {
    local TARGET="$1"
    local SCHEMA=$(get_schema_version)

    if [[ -z "$SCHEMA" ]]; then
        echo "🆕 No existing schema found. Proceeding with clean install..."
        return 0
    fi

    echo "🔍 Detected existing DB schema version: $SCHEMA"
    if [[ "$SCHEMA" < "9.9" && "$TARGET" == "25.4.0" ]]; then
        echo "❌ Cannot upgrade directly to 25.4.0 from $SCHEMA. Please upgrade to 24.12.0 first."
        exit 1
    elif [[ "$SCHEMA" == "10.7.0" && "$TARGET" == "25.4.0" ]]; then
        echo "🔄 Intermediate upgrade: 10.7.0 → 24.12.0 → 25.4.0"
        install_sonarqube "24.12.0"
        sleep 10
        sudo systemctl stop sonarqube
        install_sonarqube "25.4.0"
    else
        install_sonarqube "$TARGET"
    fi
}

# === MAIN FLOW ===

if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️ Existing SonarQube installation detected at $INSTALL_DIR"
    echo "Choose upgrade version:"
    select UPGRADE_VERSION in "${VERSIONS[@]}" "Exit"; do
        case $UPGRADE_VERSION in
            "Exit") echo "Exiting."; exit 0 ;;
            *) if [[ " ${VERSIONS[*]} " == *" $UPGRADE_VERSION "* ]]; then
                echo "🔄 Backing up to $BACKUP_DIR"
                sudo mv "$INSTALL_DIR" "$BACKUP_DIR"
                sudo -u postgres pg_dump sonarqube > ~/sonarqube_db_backup_$(date +%F_%T).sql
                install_dependencies
                create_postgres_user_and_db
                configure_limits
                create_sonar_user
                safe_upgrade_path "$UPGRADE_VERSION"
                install_nginx_proxy
                echo "✅ Upgrade to SonarQube $UPGRADE_VERSION complete."
                exit 0
            fi ;;
        esac
    done
else
    echo "🆕 No existing installation found. Choose version to install:"
    select INSTALL_VERSION in "${VERSIONS[@]}" "Exit"; do
        case $INSTALL_VERSION in
            "Exit") echo "Exiting."; exit 0 ;;
            *) if [[ " ${VERSIONS[*]} " == *" $INSTALL_VERSION "* ]]; then
                install_dependencies
                create_postgres_user_and_db
                configure_limits
                create_sonar_user
                install_sonarqube "$INSTALL_VERSION"
                install_nginx_proxy
                echo "✅ SonarQube $INSTALL_VERSION installed successfully."
                exit 0
            fi ;;
        esac
    done
fi

