#!/usr/bin/env bash

COUNT_BY_MINUTE="${2:-1}"
SLEEP=$((60/$COUNT_BY_MINUTE))
PROMETHEUS_URL="${1:-http://192.168.2.183:9091}"

echo "It will be executed every $SLEEP secondes"
echo "Used URL is $PROMETHEUS_URL"

startMetrics() {
  # Disks
  TMP="/tmp/hdd.$$.$(date +%s)"
  {
    echo "# TYPE temperature gauge"
    echo "# HELP temperature Component Temperature"
    for i in sda sdb sdc sdd sde sdf sdg sdh
    do
      smartctl -x /dev/$i |  grep "194 Temperature_Celsius" | \
        awk -v hdd=$i '{
          print("temperature{sensor=\""hdd"\"} " $8);
        }'
    done
  } > $TMP

  curl --data-binary @$TMP "$PROMETHEUS_URL/metrics/job/temperature_disk/instance/pve"

  [[ -f "$TMP" ]] && rm -rf "$TMP"

  # CPU and Motherboard
  sensors | \
    egrep "PHY Temperature|MAC Temperature|temp1|Tctl|Tccd1|Tccd2|Core" | \
    sed 's/°C//g' | \
    sed -E 's/\(.*?\)//g' | \
    sed 's/ Temperature/_Temperature/g' | \
    sed 's/://g' | \
    sed 's/e /e/g' | \
    awk 'BEGIN{
        print("# TYPE temperature gauge");
        print("# HELP temperature Component Temperature");
      }
      {
      print("temperature{sensor=\""$1"\"} " $2);
    }' | \
    sed 's/+//g' | \
    curl --data-binary @- "$PROMETHEUS_URL/metrics/job/temperature_cpu/instance/pve"
}

for i in $(seq 1 $COUNT_BY_MINUTE); do
  startMetrics

  echo "sleep $SLEEP seconds"
  sleep $SLEEP
done
