#!/usr/bin/env bash

# Pure bash data fetcher without subshells

{ while read -r name u n s i io ir so st g gn; do [[ "$name" == "cpu" ]] && { u1=$u; n1=$n; s1=$s; i1=$i; io1=$io; ir1=$ir; so1=$so; st1=$st; break; }; done; } < /proc/stat
{ rx1=0; tx1=0; while read -r iface r1 r2 r3 r4 r5 r6 r7 r8 t1 t2 t3 t4 t5 t6 t7 t8; do [[ "$iface" =~ ^(en|eth|enp|eno|ens|enx|wl|wlp|wlan|wlo|wlx) ]] && ((rx1+=r1, tx1+=t1)); done; } < /proc/net/dev

sleep 0.5

{ while read -r name u n s i io ir so st g gn; do [[ "$name" == "cpu" ]] && { u2=$u; n2=$n; s2=$s; i2=$i; io2=$io; ir2=$ir; so2=$so; st2=$st; break; }; done; } < /proc/stat
{ rx2=0; tx2=0; while read -r iface r1 r2 r3 r4 r5 r6 r7 r8 t1 t2 t3 t4 t5 t6 t7 t8; do [[ "$iface" =~ ^(en|eth|enp|eno|ens|enx|wl|wlp|wlan|wlo|wlx) ]] && ((rx2+=r1, tx2+=t1)); done; } < /proc/net/dev

IDLE1=$i1; TOTAL1=$((u1 + n1 + s1 + i1 + io1 + ir1 + so1 + st1))
IDLE2=$i2; TOTAL2=$((u2 + n2 + s2 + i2 + io2 + ir2 + so2 + st2))
DIFF_IDLE=$((IDLE2 - IDLE1))
DIFF_TOTAL=$((TOTAL2 - TOTAL1))
if [ "$DIFF_TOTAL" -eq 0 ]; then CPU_USAGE=0; else CPU_USAGE=$(( 100 * (DIFF_TOTAL - DIFF_IDLE) / DIFF_TOTAL )); fi

# SAMPLE_WINDOW_DECI is the `sleep` interval between the two reads above,
# expressed in tenths of a second (0.5s -> 5) because bash arithmetic is
# integer-only. Keeping the divisor next to the sleep it must agree with stops
# the reported rate silently doubling if the interval is ever tuned.
SAMPLE_WINDOW_DECI=5
RX_RATE=$(( (rx2 - rx1) * 10 / SAMPLE_WINDOW_DECI ))
TX_RATE=$(( (tx2 - tx1) * 10 / SAMPLE_WINDOW_DECI ))

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

echo "$CPU_USAGE|$RAM_PCT|$RAM_GB|$TEMP|$RX_RATE|$TX_RATE"
