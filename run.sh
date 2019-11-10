#!/bin/bash

if [ -f "./private/pushover.sh" ]; then
	. ./private/pushover.sh
else
	pushover_user=""
	pushover_token=""
fi

pushover_sound_success="classical"
pushover_sound_failure="falling"

dry=0
notify=0

batch_args() {
	local p="$1"
	for b in $(sed -rn 's/^\[Batch::(.*)\]$/\1/p' < bakeoff.batch); do
		if [[ $p == "all" ]] || [[ $b =~ $p ]]; then
			echo -n " -b $b"
		fi
	done
}

dry_arg() {
	[ $dry == 1 ] && echo "--batch-dry-run"
}

send_pushover() {
	local r=$1
	local sound
	local msg

	stohms() {
		date -d@$1 -u +%H:%M:%S
	}

	if [ $r -eq 0 ]; then
		sound=$pushover_sound_success
		msg="Flent run successful in $(stohms $SECONDS)!"
	else
		sound=$pushover_sound_failure
		msg="Flent run failed in $(stohms $SECONDS)."
	fi

	if [ "$pushover_user" != "" ]; then
		response=$(/usr/bin/curl -s --retry 3 --form-string token=$pushover_token --form-string user=$pushover_user --form-string "sound=$sound" --form-string "message=$msg" https://api.pushover.net/1/messages.json)

		if [[ ! "$response" == *"\"status\":1"* ]]; then
			echo "$response"
		fi
	fi
}

cleanup() {
	local u=$(whoami)
	local g=$(groups | cut -f1 -d " ")
	for d in $(find . -mindepth 1 -maxdepth 1 -type d); do
		sudo chown -R $u:$g "$d"
	done
}

usage() {
	echo "usage: $0 [batch pattern or all] <dry>"
	exit 1
}

if [[ $# == 0 ]]; then
	usage
fi

pattern="$1"
shift

while test $# -gt 0
do
	case "$1" in
	dry) dry=1
		;;
	notify) notify=1
		;;
	*) echo "unknown argument $1"
		usage
		;;
	esac
	shift
done

trap cleanup EXIT

SECONDS=0
sudo flent --batch-no-timestamp -B bakeoff.batch $(batch_args $pattern) $(dry_arg) --batch-no-shuffle

if [ $notify == 1 ]; then
	send_pushover $?
fi
