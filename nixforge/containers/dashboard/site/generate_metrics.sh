#!/usr/bin/env bash
#set -euxo pipefail
export LC_ALL=C
export PATH=/run/current-system/sw/bin:$PATH

# Autodetectar ruta de salida
if [ -d /etc/nginx/html ]; then
  OUT="/etc/nginx/html/metrics.json"
else
  OUT="/var/lib/metrics/metrics.json"
fi

# CPU global
read cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
total1=$((user + nice + system + idle + iowait + irq + softirq + steal))
idle1=$idle
sleep 1
read cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
total2=$((user + nice + system + idle + iowait + irq + softirq + steal))
idle2=$idle
CPU=$(echo "scale=1; 100 * ($total2 - $idle2 - ($total1 - $idle1)) / ($total2 - $total1)" | bc)

RAM=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100.0}')
SWAP=$(free | awk '/Swap:/ { if ($2 == 0) print 0; else printf "%.1f", $3/$2 * 100.0 }')
DISK=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
LOAD=$(uptime | awk -F 'load average:' '{ print $2 }' | cut -d, -f1 | sed 's/^ *//')
UPTIME_SEC=$(cut -d. -f1 /proc/uptime)
USERS=$(who | wc -l)
NET_DEV=$(ip route get 1 2>/dev/null | awk '{print $5; exit}')
NET_RX=$(cat /sys/class/net/"$NET_DEV"/statistics/rx_bytes 2>/dev/null || echo 0)
NET_TX=$(cat /sys/class/net/"$NET_DEV"/statistics/tx_bytes 2>/dev/null || echo 0)

# Temperaturas
TEMP_RAW=$(sensors 2>/dev/null || true)

# Extraer valores con control de errores y formato seguro
get_temp_value() {
  local label="$1"
  local val=$(echo "$TEMP_RAW" | grep -m 1 "$label" | awk '{print $2}' | tr -d '+°C')
  if [[ "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "$val"
  else
    echo "null"
  fi
}

TEMP_CPU0=$(get_temp_value "Core 0:")
TEMP_CPU1=$(get_temp_value "Core 1:")
TEMP_NVME=$(get_temp_value "Composite:")

# Promedio de temperaturas (de todos los cores)
TEMP_LIST=$(echo "$TEMP_RAW" | grep -E 'Core [0-9]:' | awk '{print $2}' | tr -d '+°C')
TEMP_SUM=0
COUNT=0
for t in $TEMP_LIST; do
  if [[ "$t" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    TEMP_SUM=$(echo "$TEMP_SUM + $t" | bc)
    COUNT=$((COUNT + 1))
  fi
done
if [ "$COUNT" -gt 0 ]; then
  TEMP=$(echo "scale=1; $TEMP_SUM / $COUNT" | bc)
else
  TEMP="null"
fi

# CPUs por hilo
CPUS_JSON=$(awk '/^cpu[0-9]+/ {
  cpu=$1;
  u=$2; n=$3; s=$4; i=$5;
  total = u + n + s + i;
  active = u + n + s;
  usage = 100 * active / total;
  printf "\"%s\": %.1f,\n", cpu, usage
}' /proc/stat)

# JSON final
{
  echo "{"
  echo "  \"cpu\": $CPU,"
  echo "  \"ram\": $RAM,"
  echo "  \"swap\": $SWAP,"
  echo "  \"disk\": $DISK,"
  echo "  \"disk_total\": \"$DISK_TOTAL\","
  echo "  \"disk_used\": \"$DISK_USED\","
  echo "  \"disk_avail\": \"$DISK_AVAIL\","
  echo "  \"load\": \"$LOAD\","
  echo "  \"uptime\": $UPTIME_SEC,"
  echo "  \"users\": $USERS,"
  echo "  \"temp\": $TEMP,"
  echo "  \"temp_cpu0\": $TEMP_CPU0,"
  echo "  \"temp_cpu1\": $TEMP_CPU1,"
  echo "  \"temp_nvme\": $TEMP_NVME,"
  echo "  \"net_iface\": \"$NET_DEV\","
  echo "  \"net_rx\": $NET_RX,"
  echo "  \"net_tx\": $NET_TX,"
  echo "$CPUS_JSON" | sed '$ s/,$//'
  echo "}"
} > "$OUT"
