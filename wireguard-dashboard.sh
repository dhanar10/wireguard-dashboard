#!/usr/bin/env bash

#set -e
#set -o pipefail

IFACE="wg0"
SERVER_IP_ADDRESS="172.22.1.1"
CLIENT_IP_ADDRESS_MIN="172.22.100.1"
CLIENT_IP_ADDRESS_MAX="172.22.199.1"
DEFAULT_ENDPOINT="182.253.115.34:51280"
DEFAULT_ALLOWED_IPS="172.22.0.0/16"

TITLE="Wireguard Dashboard"

add()
{
	while true; do
		exec 3>&1
		ENTERED_NAME=$(whiptail --inputbox "Name (e.g. ubuntu-laptop)" 8 78 "" --title "$TITLE" 2>&1 1>&3)
		STATUS=$?
		exec 3>&-
		
		[[ $STATUS == 1 || $STATUS == 255 ]] && break
	
		exec 3>&1
		ENTERED_PUBLIC_KEY=$(whiptail --inputbox "Public Key" 8 78 "" --title "$TITLE" 2>&1 1>&3)
		STATUS=$?
		exec 3>&-
		
		[[ $STATUS == 1 || $STATUS == 255 ]] && break
	
		exec 3>&1
		ENTERED_IP_ADDRESS=$(whiptail --inputbox "IP Address ($DEFAULT_ALLOWED_IPS)" 8 78 "$SERVER_IP_ADDRESS" --title "$TITLE" 2>&1 1>&3)
		STATUS=$?
		exec 3>&-
		
		[[ $STATUS == 1 || $STATUS == 255 ]] && break
		
		IP_ADDRESS_USED=0

		if [ "x$SERVER_IP_ADDRESS" == "x$ENTERED_IP_ADDRESS" ]; then
			IP_ADDRESS_USED=1
		fi
		
		if wg show $IFACE dump | tail +2 | awk '{ print $4 }' | grep -q "^$ENTERED_IP_ADDRESS/"; then
			IP_ADDRESS_USED=1
		fi
		
		if [ $IP_ADDRESS_USED -ne 0 ]; then
			exec 3>&1
			whiptail --title "$TITLE" --msgbox "IP address $ENTERED_IP_ADDRESS is already being used!" 8 78 2>&1 1>&3
			STATUS=$?
			exec 3>&-
			
			continue
		fi
		
		wg set wg0 peer "$ENTERED_PUBLIC_KEY" allowed-ips "$ENTERED_IP_ADDRESS" \
			&& wg-quick save wg0 \
			&& touch /etc/wireguard/$IFACE.meta \
			&& sed -i -e "\:^$ENTERED_PUBLIC_KEY:d" /etc/wireguard/$IFACE.meta \
			&& echo -e "$ENTERED_PUBLIC_KEY\t$ENTERED_NAME" >> /etc/wireguard/$IFACE.meta

		echo

		clear
		cat << EOF
[Interface]
PrivateKey = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX # TODO Fill in your private key
Address = $ENTERED_IP_ADDRESS/32

[Peer]
PublicKey = $(wg show wg0 public-key)
AllowedIPs = $DEFAULT_ALLOWED_IPS # TODO Modify as required
Endpoint = $DEFAULT_ENDPOINT
PersistentKeepalive = 25
EOF

		read
		
		break
	done
}

remove()
{
	while true; do
		declare -A META
		
		IFS=$'\n'
		for LINE in $(cat /etc/wireguard/$IFACE.meta); do
			PUBLIC_KEY=$(echo "$LINE" | cut -f 1)
			NAME=$(echo "$LINE" | cut -f 2)
			META["$PUBLIC_KEY"]="$NAME"
		done
		unset IFS

		LIST=()
		
		IFS=$'\n'
		for LINE in $(wg show $IFACE dump | tail +2 | awk '{ print $1"\t"$4 }'); do
			PUBLIC_KEY=$(echo "$LINE" | cut -f 1)
			ALLOWED_IPS=$(echo "$LINE" | cut -f 2)
			LIST+=( "$PUBLIC_KEY" " $ALLOWED_IPS ${META[$PUBLIC_KEY]}" )
		done
		unset IFS
		
		exec 3>&1
		SELECTED_PUBLIC_KEY=$(whiptail --title "$TITLE" --menu "Remove a Peer" 25 118 16 "${LIST[@]}" 2>&1 1>&3)
		STATUS=$?
		exec 3>&-
		
		[[ $STATUS == 1 || $STATUS == 255 ]] && break
		
		exec 3>&1
		whiptail --yesno "Remove peer ${META[$SELECTED_PUBLIC_KEY]}?" 8 78 --title "$TITLE" 2>&1 1>&3
		STATUS=$?
		exec 3>&-
		
		[[ $STATUS == 1 || $STATUS == 255 ]] && continue
		
		wg set $IFACE peer $SELECTED_PUBLIC_KEY remove \
			&& wg-quick save wg0 \
			&& touch /etc/wireguard/$IFACE.meta \
			&& sed -i -e "\:^$SELECTED_PUBLIC_KEY:d" /etc/wireguard/$IFACE.meta
	done
}

while true; do
  LIST=()

  LIST+=("add" "Add a peer")
  LIST+=("remove" "Remove a peer")
  #LIST+=("backup" "Backup configuration")

  exec 3>&1
  TASK=$(whiptail --title "$TITLE" --menu "Select a task" 25 78 16 "${LIST[@]}" 2>&1 1>&3)
  STATUS=$?
  exec 3>&-

  [[ $STATUS == 1 || $STATUS == 255 ]] && clear && exit

  case $TASK in
    add)
       add
       ;;
    remove)
       remove
       ;;
  esac
done