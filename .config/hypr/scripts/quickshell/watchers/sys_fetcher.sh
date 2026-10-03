#!/usr/bin/env bash

# Pure bash data fetcher with persistent state across calls (0ms sleep)
RUNDIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell"
mkdir -p "$RUNDIR"
STATE_FILE="$RUNDIR/sys_fetcher_state"

NOW=$(date +%s%N)
read -r _ u n s i io ir so st _ < /proc/stat
TOT=$((u + n + s + i + io + ir + so + st))
IDL=$i

CORES=$(nproc 2>/dev/null || echo 4)

RX=0; TX=0
while read -r iface r1 r2 r3 r4 r5 r6 r7 r8 t1 t2 t3 t4 t5 t6 t7 t8; do
    [[ "$iface" =~ ^(en|eth|enp|eno|ens|enx|wl|wlp|wlan|wlo|wlx) ]] && ((RX+=r1, TX+=t1))
done < /proc/net/dev

CPU_USAGE=0; RX_RATE=0; TX_RATE=0

if [ -f "$STATE_FILE" ]; then
    read -r P_NOW P_TOT P_IDL P_RX P_TX < "$STATE_FILE"
    DIFF_NSEC=$((NOW - P_NOW))
    DIFF_TOT=$((TOT - P_TOT))
    DIFF_IDL=$((IDL - P_IDL))
    if [ "$DIFF_TOT" -gt 0 ]; then
        CPU_USAGE=$(( 100 * (DIFF_TOT - DIFF_IDL) / DIFF_TOT ))
    fi
    if [ "$DIFF_NSEC" -gt 100000000 ]; then
        RX_RATE=$(( (RX - P_RX) * 1000000000 / DIFF_NSEC ))
        TX_RATE=$(( (TX - P_TX) * 1000000000 / DIFF_NSEC ))
    fi
else
    # Cold start: quick 0.1s sample once
    sleep 0.1
    read -r _ u2 n2 s2 i2 io2 ir2 so2 st2 _ < /proc/stat
    TOT2=$((u2 + n2 + s2 + i2 + io2 + ir2 + so2 + st2))
    IDL2=$i2
    DIFF_TOT=$((TOT2 - TOT))
    DIFF_IDL=$((IDL2 - IDL))
    if [ "$DIFF_TOT" -gt 0 ]; then
        CPU_USAGE=$(( 100 * (DIFF_TOT - DIFF_IDL) / DIFF_TOT ))
    fi
fi

echo "$NOW $TOT $IDL $RX $TX" > "$STATE_FILE"

# RAM
while IFS=": " read -r key val _; do
    case "$key" in
        MemTotal) TOTAL_MEM="${val// /}" ;;
        MemAvailable) AVAIL_MEM="${val// /}" ;;
    esac
done < /proc/meminfo
USED_MEM=$((TOTAL_MEM - AVAIL_MEM))
RAM_PCT=$(( 100 * USED_MEM / TOTAL_MEM ))
USED_MB=$((USED_MEM / 1024))
RAM_GB="$((USED_MB / 1024)).$(( (USED_MB % 1024) * 10 / 1024 ))"

# Temperature
TEMP_RAW=""
for hwmon in /sys/class/hwmon/hwmon*; do
    if [ -f "$hwmon/name" ]; then
        read -r hwmon_name < "$hwmon/name"
        if [[ "$hwmon_name" =~ ^(coretemp|k10temp|zenpower|cpu_thermal|bcm2835_thermal)$ ]]; then
            if [ -f "$hwmon/temp1_input" ]; then
                read -r TEMP_RAW < "$hwmon/temp1_input"
                break
            fi
        fi
    fi
done

if [ -z "$TEMP_RAW" ]; then
    for tz in /sys/class/thermal/thermal_zone*; do
        if [ -f "$tz/type" ]; then
            read -r tz_type < "$tz/type"
            if [[ "$tz_type" =~ ^(x86_pkg_temp|cpu_thermal|cpu-thermal)$ ]]; then
                read -r TEMP_RAW < "$tz/temp"
                break
            fi
        fi
    done
fi

if [ -z "$TEMP_RAW" ]; then
    if [ -f /sys/class/hwmon/hwmon0/temp1_input ]; then
        read -r TEMP_RAW < /sys/class/hwmon/hwmon0/temp1_input
    elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        read -r TEMP_RAW < /sys/class/thermal/thermal_zone0/temp
    else
        TEMP_RAW=0
    fi
fi

if ! [[ "$TEMP_RAW" =~ ^[0-9]+$ ]]; then
    TEMP_RAW=0
elif [ "$TEMP_RAW" -gt 1000 ]; then
    TEMP=$((TEMP_RAW / 1000))
else
    TEMP=$TEMP_RAW
fi

echo "$CPU_USAGE|$RAM_PCT|$RAM_GB|$TEMP|$RX_RATE|$TX_RATE|$CORES"
