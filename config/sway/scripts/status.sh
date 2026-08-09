#!/usr/bin/env bash
set -euo pipefail

get_cpu_usage() {
    read -r _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
    local idle1_all=$((idle1 + iowait1))
    local total1=$((user1 + nice1 + system1 + idle1_all + irq1 + softirq1 + steal1))

    sleep 1

    read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat
    local idle2_all=$((idle2 + iowait2))
    local total2=$((user2 + nice2 + system2 + idle2_all + irq2 + softirq2 + steal2))

    local total_diff=$((total2 - total1))
    local idle_diff=$((idle2_all - idle1_all))

    echo $(( (100 * (total_diff - idle_diff)) / total_diff ))
}

get_mem_usage() {
    # $3=used(MB) $2=total(MB) from `free -m`
    free -m | awk '/^Mem:/ {printf "%.1fGB / %.1fGB (%.0f%%)", $3/1024, $2/1024, ($3/$2)*100}'
}

get_cpu_temp() {
    # First "+NN.N°C" reading; works for coretemp/k10temp/most chips.
    sensors | grep -m1 -oP '\+\K[0-9]+\.[0-9]+(?=°C)' || echo "N/A"
}

while true; do
    cpu_pct=$(get_cpu_usage)          # this call also provides the 1s sample interval
    mem=$(get_mem_usage)
    temp=$(get_cpu_temp)
    ts=$(date "+%Y-%m-%d %I:%M %p")

    echo "MEM: ${mem} | CPU: ${cpu_pct}% | Temp: ${temp}°C | ${ts}"
done
