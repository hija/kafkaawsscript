#!/bin/bash

kafka_path="/opt/kafka/"

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function find_kafka_config() {
  config_path="${kafka_path%/}/config/server.properties"
  if [ ! -f $config_path ]; then
    echo -e "${RED}[FATAL]${NC} The server.properties could not be found. Did you specify the kafka_path in this file?"
    exit 1
  fi

  # Check if config is valid, i.e. if it contains connection value
  if ! grep -q "zookeeper.connect=" $config_path; then
    echo -e "${RED}[FATAL]${NC} The entry for zookeeper connect could not be found. Maybe this script is outdated or your installation broken"
    exit 1
  fi
}

function restart_kafka() {
  if (whiptail --title "Change successful" --yesno "The zookeeper ip for kafka has been changed. Do you want to run kafka now?" 8 78) then
    echo -e "[INFO] Starting Kafka..."
    sh "${kafka_path%/}/bin/kafka-server-start.sh" $config_path
  else
    echo -e "[INFO] Done."
  fi
}

function change_zookeeper_ip() {
  # Easy using sed
  sed -i "s/^\(zookeeper\.connect=\).*\$/\1$1/" $config_path
  echo -e "${GREEN}[DONE]${NC} The ip has been changed succesfully!"
}

function show_ip_window_change() {
  ERM_IP=$(whiptail --inputbox "Enter the ip of your ERM-Cluster" 8 78 --title "ERM-Cluster IP" --backtitle "Kafka Setup"  3>&1 1>&2 2>&3)

  # Remove http and https and trailing slash, so we can parse the ip from AWS directly
  ERM_IP="${ERM_IP#http://}"
  ERM_IP="${ERM_IP#https://}"
  ERM_IP="${ERM_IP%/}"

  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "[INFO] User has entered the following ip:" $ERM_IP
  else
    echo -e "${YELLOW}[CANCEL]${NC} The user decided to cancel the process!"
    exit 0
  fi
}

function check_ip() {
  if ! ping -c 1 $1 &> /dev/null; then
    if (whiptail --title "Server no ping response" --yesno "The server did not answer a ping request. Do you still want to set it as a zookeeper server?" 8 78) then
      return
    else
      echo -e "${YELLOW}[CANCEL]${NC} The user decided to cancel the process after zookeeper could not be pinged!"
      exit 0
    fi
  fi
}

function main() {
  # Check if user is root
  if [[ ! $EUID -eq 0 ]]; then
    echo -e "${RED}[FATAL]${NC} You need to be root to run this script"
    exit 1
  fi

  # Check if kafka setup is as expected
  find_kafka_config

  # Show set ip dialog
  show_ip_window_change
  check_ip $ERM_IP
  change_zookeeper_ip $ERM_IP

  # Ask if restart kafka
  restart_kafka
}

main
