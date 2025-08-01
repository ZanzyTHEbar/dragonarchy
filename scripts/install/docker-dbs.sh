#!/bin/bash
# Interactively sets up and launches common databases in Docker.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1"; }

log_info "Select databases to launch as Docker containers."
options=("MariaDB" "MySQL" "Redis" "PostgreSQL")
choices=$(printf "%s\n" "${options[@]}" | gum choose --no-limit --header="Select databases (space to select, return to install, esc to cancel)")

if [[ -n "$choices" ]]; then
  for db in $choices; do
    log_info "Launching $db container..."
    case $db in
    MySQL) sudo docker run -d --restart unless-stopped -p "127.0.0.1:3306:3306" --name=mysql8 -e MYSQL_ROOT_PASSWORD= -e MYSQL_ALLOW_EMPTY_PASSWORD=true mysql:8.4 ;;
    PostgreSQL) sudo docker run -d --restart unless-stopped -p "127.0.0.1:5432:5432" --name=postgres16 -e POSTGRES_HOST_AUTH_METHOD=trust postgres:16 ;;
    MariaDB) sudo docker run -d --restart unless-stopped -p "127.0.0.1:3307:3306" --name=mariadb11 -e MARIADB_ROOT_PASSWORD= -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=true mariadb:11.8 ;; # Note: Port changed to 3307 to avoid conflict with MySQL
    Redis) sudo docker run -d --restart unless-stopped -p "127.0.0.1:6379:6379" --name=redis redis:7 ;;
    esac
  done
  log_info "Selected database containers have been launched."
else
    log_info "No databases selected. Exiting."
fi
