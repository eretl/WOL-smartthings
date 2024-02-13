#!/bin/bash
#EDIT PARAMETERS-----------------------------------------------------
API_URL="https://api.smartthings.com/v1"

#https://account.smartthings.com/tokens
#x:devices:*,l:devices,r:devices:*,w:devices:*
ACCESS_TOKEN="YOUR-TOKEN"

#https://my.smartthings.com/advanced/devices
#Add new device with switch type
#DEVICE_1, DEVICE_2, DEVICE_3, ...
DEVICE_ID=("YOUR-DEVICE-ID_1" "YOUR-DEVICE-ID_2" "YOUR-DEVICE-ID_3")
DEVICE_IP=("YOUR-DEVICE-IP_1" "YOUR-DEVICE-IP_2" "YOUR-DEVICE-IP_3")
DEVICE_MAC=("YOUR-DEVICE-MAC_1" "YOUR-DEVICE-MAC_2" "YOUR-DEVICE-MAC_3")

#Name of WOL interface on synology
SYNOLOGY_ETHER_PORT="ovs_eth0"

#END OF EDIT-----------------------------------------------------
AUTH_HEADER="Authorization: Bearer $ACCESS_TOKEN"
CONTENT_HEADER="Content-Type: application/json"


#DEVICEID, DEVICEIP, DEVICEMAC
function switch_logic() {
  switch_enabled=0
  
  #DEVICEMAC
  function switch_on() {
    synonet --wake "$1" $SYNOLOGY_ETHER_PORT
    switch_enabled=1
    sleep 15
  }

  function switch_off() {
    switch_enabled=0
  }

  while true; do
    response=$(curl -s -H "$AUTH_HEADER" -H "$CONTENT_HEADER" "$API_URL/devices/$1/status")
    #echo $1
    switch_state=$(jq -r '.components.main.switch.switch.value' <<< "$response")

    if [ "$switch_state" = "on" ]; then
      if [ "$switch_enabled" -eq "0" ]; then
        switch_on $3
      fi
      if ping -c 1 $2 &> /dev/null; then 
        echo "Ping on" > /dev/null
      else
        response=$(curl -s -H "$AUTH_HEADER" -H "$CONTENT_HEADER" -X POST -d '{
          "commands": [
          {
            "component": "main",
            "capability": "switch",
            "command": "off"
          }
          ]
        }' "$API_URL/devices/$1/commands")
      fi
    fi

    if [ "$switch_state" = "off" ]; then
      if [ "$switch_enabled" -eq "1" ]; then
        switch_off
      fi
    if ping -c 1 $2 &> /dev/null; then 
      response=$(curl --silent --header "Authorization: Bearer $ACCESS_TOKEN" --header "Content-Type: application/json" -X POST -d '{
        "commands": [
        {
          "component": "main",
          "capability": "switch",
          "command": "on"
        }
        ]
      }' "$API_URL/devices/$1/commands")
    fi
  fi
  #echo "Sw:$switch_enabled"
  sleep 5
  done
}

function main() {
    for sw in ${!DEVICE_ID[*]}; do  
    #echo ${DEVICE_ID[sw]} ${DEVICE_IP[sw]} ${DEVICE_MAC[sw]}
      switch_logic ${DEVICE_ID[sw]} ${DEVICE_IP[sw]} ${DEVICE_MAC[sw]} &
    done
}

main