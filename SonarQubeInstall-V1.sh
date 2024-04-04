#!/bin/bash

sudo apt update

# Install default JDK
sudo apt install default-jdk -y

# Add PostgreSQL repository and install PostgreSQL 15
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
sudo apt update
sudo apt install postgresql-15 -y

# Check PostgreSQL status and create database and user
sudo systemctl is-enabled postgresql
sudo systemctl status postgresql
sudo -u postgres psql <<EOF
CREATE USER sonarqube WITH PASSWORD 'uuUU123!@#';
CREATE DATABASE sonarqube OWNER sonarqube;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;
\l
\du
\q
EOF

# Create sonarqube user
sudo useradd -b /opt/sonarqube -s /bin/bash sonarqube

# Configure system parameters
sudo bash -c 'echo "vm.max_map_count=524288" >> /etc/sysctl.conf'
sudo bash -c 'echo "fs.file-max=131072" >> /etc/sysctl.conf'
sudo sysctl --system
ulimit -n 131072
ulimit -u 8192
sudo bash -c 'echo "sonarqube - nofile 131072" >> /etc/security/limits.d/99-sonarqube.conf'
sudo bash -c 'echo "sonarqube - nproc 8192" >> /etc/security/limits.d/99-sonarqube.conf'

# Install necessary tools
sudo apt install unzip software-properties-common wget -y

# Download and install SonarQube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.4.1.88267.zip
unzip sonarqube-10.4.1.88267.zip
mv sonarqube-10.4.1.88267 /opt/sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# Configure SonarQube settings
sudo bash -c 'cat <<EOF > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonarqube
sonar.jdbc.password=uuUU123!@#
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m -XX:+HeapDumpOnOutOfMemoryError
sonar.web.host=127.0.0.1
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.log.level=INFO
sonar.path.logs=logs
EOF'

# Create systemd unit file for SonarQube
sudo bash -c 'cat <<EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd, start and enable SonarQube service
sudo systemctl daemon-reload
sudo systemctl start sonarqube.service
sudo systemctl enable sonarqube.service
#sudo systemctl status sonarqube.service

# Install and configure Nginx
sudo apt install nginx -y
sudo systemctl is-enabled nginx && sudo systemctl status nginx
sudo bash -c 'cat <<EOF > /etc/nginx/sites-available/sonarqube.conf
server {
    listen 80;
    server_name sonarqube.booleanlabs.biz;
    access_log /var/log/nginx/sonar.access.log;
    error_log /var/log/nginx/sonar.error.log;
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
    }
}
EOF'
sudo ln -s /etc/nginx/sites-available/sonarqube.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo apt install net-tools -y
