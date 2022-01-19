#!/usr/bin/env bash
set -euo pipefail

function killService() {
    service=$1
    sudo systemctl stop "${service}"
    sudo systemctl kill --kill-who=all "${service}"

    # this wait does _not_ work
    while ! (sudo systemctl status "$service" | grep -q "Main.*code=\(exited\|killed\)")
    do
        echo "waiting on ${service}"
        sleep 10
    done
}

function disableTimers() {
    sudo systemctl disable apt-daily.timer
    sudo systemctl disable apt-daily-upgrade.timer
}

function killServices() {
    killService unattended-upgrades.service
    killService apt-daily.service
    killService apt-daily-upgrade.service
}

function main() {
    disableTimers
    killServices
}

main
