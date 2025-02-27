#!/bin/bash
# Sdript to check if public IP has changed and, if so, update Cloudflare DNS
#
CLOUDFLARE_API_TOKEN="<<CLOUDFLARE_API_TOKEN>>"
ZONE_ID="<<ZONE_ID>>"
DNS_RECORD_ID="<<DNS_RECORD_ID>>"
DNS_RECORD_NAME="<<DOMAIN>>"
DNS_RECORD_TYPE="A"

CURRENT_DATETIME="$(date +'%Y-%m-%d %H:%M:%S')"
LOGFILE=/var/log/update-ddns/"$(date +'%Y%m%d')"_update-ddns.log

# Define the full paths to commands to be able run this script with cron
CURL="/usr/bin/curl"
JQ="/usr/bin/jq"

# Get the current public IP address
IP=$($CURL -s http://ipv4.icanhazip.com)

# Cloudflare API endpoint to get the current DNS record
GET_API_ENDPOINT="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_RECORD_ID"

# Get the current DNS record's IP address from Cloudflare
current_ip=$($CURL -s -X GET "$GET_API_ENDPOINT" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     -H "Content-Type: application/json" | $JQ -r '.result.content')

# Check if the IP addresses are different
if [[ "$IP" == "$current_ip" ]]; then
  echo "$CURRENT_DATETIME : No update needed. IP address has not changed: $IP" >> $LOGFILE
else
  echo "$CURRENT_DATETIME : IP address has changed from $current_ip to $IP. Updating record..."

  # Cloudflare API endpoint to update the DNS record
  UPDATE_API_ENDPOINT="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_RECORD_ID"

  # Update the DNS record
  response=$($CURL -s -X PUT "$UPDATE_API_ENDPOINT" \
       -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
       -H "Content-Type: application/json" \
       --data '{
         "type": "'"$DNS_RECORD_TYPE"'",
         "name": "'"$DNS_RECORD_NAME"'",
         "content": "'"$IP"'",
         "ttl": 120,
         "proxied": true
       }')

  # Check if the update was successful
  if [[ $response == *"\"success\":true"* ]]; then
    echo "DNS record updated successfully to IP: $IP"
  else
    echo "Failed to update DNS record. Response: $response"
  fi
fi
