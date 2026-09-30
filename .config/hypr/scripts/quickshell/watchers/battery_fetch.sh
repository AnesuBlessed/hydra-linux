#!/usr/bin/env bash
get_battery_percent() {
    local p
    p=$(LC_ALL=C cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
    if [[ -n "$p" && "$p" =~ ^[0-9]+$ ]]; then
        echo "$p"
    else
        echo "100"
    fi
}

get_battery_status() {
    local s
    s=$(LC_ALL=C cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)
    if [[ -n "$s" ]]; then
        echo "$s"
    else
        echo "Full"
    fi
}

get_battery_icon() {
    local percent
    percent=$(get_battery_percent)
    local status
    status=$(get_battery_status)
    if ! [[ "$percent" =~ ^[0-9]+$ ]]; then
        percent=100
    fi

    if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
        if [ "$percent" -ge 90 ]; then echo "󰂅"
        elif [ "$percent" -ge 80 ]; then echo "󰂋"
        elif [ "$percent" -ge 60 ]; then echo "󰂊"
        elif [ "$percent" -ge 40 ]; then echo "󰢞"
        elif [ "$percent" -ge 20 ]; then echo "󰂆"
        else echo "󰢜"; fi
    else
        if [ "$percent" -ge 90 ]; then echo "󰁹"
        elif [ "$percent" -ge 80 ]; then echo "󰂂"
        elif [ "$percent" -ge 70 ]; then echo "󰂁"
        elif [ "$percent" -ge 60 ]; then echo "󰂀"
        elif [ "$percent" -ge 50 ]; then echo "󰁿"
        elif [ "$percent" -ge 40 ]; then echo "󰁾"
        elif [ "$percent" -ge 30 ]; then echo "󰁽"
        elif [ "$percent" -ge 20 ]; then echo "󰁼"
        elif [ "$percent" -ge 10 ]; then echo "󰁻"
        else echo "󰁺"; fi
    fi
}

jq -n -c --arg percent "$(get_battery_percent)" --arg status "$(get_battery_status)" --arg icon "$(get_battery_icon)" '{percent: $percent, status: $status, icon: $icon}'
