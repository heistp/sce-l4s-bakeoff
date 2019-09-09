#!/bin/bash

DEBUG=0
TMPDIR="/tmp/sce-l4s-bakeoff"
DATADIR="$TMPDIR/data"
LOGDIR="$TMPDIR/log"
PHASE=

flent_setup() {
	setup_all setup "$@"
}

flent_teardown() {
	setup_all teardown "$@"
}

flent_clear() {
	local dsts="$1"

	for d in $(split $dsts); do
		ssh $d sudo bash -s clear_setup < commands.sh
	done
}

clear_setup() {
	for d in $(tc qdisc | awk '$3!="0:" && !x[$5]++ {print $5}'); do
		runq tc qdisc del dev $d root || true
		[[ $d != ifb* ]] && runq tc qdisc del dev $d ingress || true
	done
	for l in `ip link show | sed -rn 's/.* (ifb\S+):.*/\1/p'`; do
		runq tc qdisc del dev $l root || true
		runq ip link del dev $l || true
	done
	runq rmmod ifb || true
	runq iptables -t mangle -F POSTROUTING || true
	runq ip tcp_metrics flush || true
}

flent_process() {
	local data_filename="$1"; shift
	local end=$(( $# / 2 ))
	local cmds=()
	local fails=0
	local n=$(basename $data_filename); n="${n%.*}"

	prepend_basenames() {
		for f in $(dirname $data_filename)/*; do
			local b=$(basename $f)
			if [[ $b != batch-* ]]; then
				mv "$f" "$(dirname $data_filename)/$n.$b" || exit 1
			fi
		done
	}

	(
		for (( i = 0; i < $end; i++ )); do
			local dst=$1; shift
			cmds+=("$1"); shift
			run scp \"$dst:$DATADIR/*\" $(dirname $data_filename) &> /dev/null || true
			prepend_basenames
		done

		for c in "${cmds[@]}"; do
			eval "PHASE=process; $c" || exit 1
		done
	) 2>&1 | tee "$(dirname $data_filename)/$n.process.log"
}

setup_all() {
	local mode=$1; shift
	local data_filename="$1"; shift
	local pids=()
	local dsts=()
	local fails=0
	local end=$(( $# / 2 ))

	host() {
		echo ${1#*@}
	}

	ofile() {
		echo "$LOGDIR/$(host $1).log"
	}

	rm -fr "$LOGDIR" || exit 1
	mkdir -p "$LOGDIR" || exit 1

	for (( i = 0; i < $end; i++ )); do
		local dst=$1; shift
		local cmd="$1"; shift
		(
			ssh $dst sudo bash -s setup $mode $(printf %q "$(printf %q "$cmd")") < commands.sh &> $(ofile $dst)
		) &
		dsts+=($dst)
		pids+=($!)
	done

	for p in ${pids[@]}; do
		wait $p || ((fails++))
	done

	(
		for d in ${dsts[@]}; do
			local h=$(host $d)
			echo $h
			echo "${h//?/-}"
			echo
			cat $(ofile $d)
			echo
			rm $(ofile $d)
		done
	) 2>&1 | tee "${data_filename}.$mode.log"
	rmdir "$LOGDIR"
	return $fails
}

setup() {
	local mode=$1; shift
	local cmd="$@"

	fail() {
		eval "PHASE=teardown; $cmd"
		exit 1
	}

	case $mode in
		setup)
			rm -fr "$DATADIR" || exit 1
			mkdir -p "$DATADIR" || exit 1
			eval "PHASE=init; $cmd" || fail
			eval "PHASE=setup; $cmd" || fail
			eval "PHASE=show_setup; $cmd; kernel_info" || fail
			;;
		teardown)
			eval "PHASE=show_teardown; $cmd" || fail
			eval "PHASE=teardown; $cmd" || fail
			;;
		*)
			echo "mode $mode not implemented"
			fail
			;;
	esac
}

tcp_metrics() {
	case $PHASE in
	init|teardown)
		runq ip tcp_metrics flush || return
		;;
	show*)
		run ip tcp_metrics show || return
		;;
	esac
}

run_tcpdump() {
	local ifaces="$1"; shift
	local p="$@"

	killpids() {
		shopt -s nullglob
		for f in $DATADIR/*.pid; do
			local pid=$(cat $f)
			kill $pid &> /dev/null || true
			while kill -0 $pid 2> /dev/null; do sleep 0.2; done;
			rm -f "$f"
		done
		shopt -u nullglob
	}

	for i in $(split $ifaces); do
		local b="$DATADIR/tcpdump_$(hostname)_$i"
		case $PHASE in
		setup)
			killpids
			nohup tcpdump -i $i -G 120 -W 1 -s 128 -w "$b.pcap" $p &> "$b.log" &
			echo $! > "$b.pid"
			;;
		init|teardown)
			killpids
			;;
		esac
	done
}

kernel_info() {
	case $PHASE in
	show_setup)
		run uname -a
		cat /boot/info-$(uname -r).txt || true
		;;
	esac
}

plot() {
	local df="$1.flent.gz"
	local title1="$2"
	local title2="$3"

	tattr() {
		local key="$1"
		local tattrs=( $title3 )

		for a in "${tattrs[@]}"; do
			IFS=":" read k v <<< "$a"
			if [ "$key" == "$k" ]; then
				echo "$v"
				return 0
			fi
		done
		echo ""
	}

	plot_tcp_1up() {
		local f="$1"
		local cc="$2"
		local rtt="${3%ms}"
		local n="${f%.flent.gz}"
		local t=$(printf "$title1\n$title2\n$title3")

		rttmax() {
			local rttscale=$1
			local rtt=$2
			if [ $rttscale == "fixed" ]; then
				echo $(( $rtt + 100 ))
			else
				gzip -dc "$df" | jq "(.results.\"Ping (ms) ICMP\"+.results.\"TCP upload::tcp_rtt\"|max-$rtt)*3+$rtt"
			fi
		}

		for rttscale in fixed var; do
			run "flent -i \"$f\" -p totals_with_tcp_rtt \
-o ${n}_$rttscale.png \
--override-title \"$t\" \
--bounds-y \"0,60\" \
--bounds-y \"$rtt,$(rttmax $rttscale $rtt)\" \
--override-label \"$cc throughput\" \
--override-label \"ICMP RTT\" \
--override-label \"TCP RTT\" \
--label-y \"Mbps\" \
--label-y \"ms\" \
--fallback-layout --figure-width=10 --figure-height=7.5 \&"
		done
		wait
	}

	plot_tcp_2up() {
		local f="$1"
		local ccs="$2"
		local rtt="${3%ms}"
		local n="${f%.flent.gz}"
		local cc1=$(cut -f1 -d "," <<< $ccs)
		local cc2=$(cut -f2 -d "," <<< $ccs)
		local t=$(printf "$title1\n$title2\n$title3")

		rttmax() {
			local rttscale=$1
			local rtt=$2
			if [ $rttscale == "fixed" ]; then
				echo $(( $rtt + 100 ))
			else
				gzip -dc "$df" | jq "(.results.\"Ping (ms) ICMP\"+.results.\"TCP upload::1::tcp_rtt\"+.results.\"TCP upload::2::tcp_rtt\"|max-$rtt)*3+$rtt"
			fi
		}

		if_l4s() {
			local s="$1"
			if [[ $(tattr b) == l4s* ]]; then
				echo " ($s)"
			fi
		}

		for rttscale in fixed var; do
			run "flent -i \"$f\" -p upload_with_ping_and_tcp_rtt \
-o ${n}_$rttscale.png \
--override-title \"$t\" \
--bounds-y \"0,60\" \
--bounds-y \"$rtt,$(rttmax $rttscale $rtt)\" \
--override-label \"$cc1 throughput\" \
--override-label \"$cc2 throughput\" \
--override-label \"ICMP RTT ECT(0)$(if_l4s "classic")\" \
--override-label \"ICMP RTT ECT(1)$(if_l4s "l4s")\" \
--override-label \"$cc1 TCP RTT\" \
--override-label \"$cc2 TCP RTT\" \
--override-label \"$cc1 TCP RTT\" \
--override-label \"$cc2 TCP RTT\" \
--label-y \"Mbps\" \
--label-y \"ms\" \
--fallback-layout --figure-width=10 --figure-height=7.5 \&"
		done
		wait
	}

	case $PHASE in
	process)
		local title3=$(gzip -dc $df | jq -r ".metadata.TITLE")
		local name=$(gzip -dc $df | jq -r ".metadata.NAME")
		case $name in
			tcp_1up)
				plot_tcp_1up "$df" \
					$(gzip -dc $df | jq -r ".metadata.TEST_PARAMETERS.tcp_cong_control") \
					$(tattr rtt)
				;;
			tcp_2up)
				plot_tcp_2up "$df" \
					$(gzip -dc $df | jq -r ".metadata.TEST_PARAMETERS.cc_algos") \
					$(tattr rtt)
				;;
			*)
				echo "unknown test name: $name"
				return 1
		esac
		;;
	esac
}

run_scetrace() {
	local dir="$1"

	case $PHASE in
	process)
		if ! type scetrace &> /dev/null; then
			echo "+ scetrace: not found"
			return
		fi
	
		shopt -s nullglob
		for f in $dir/*.pcap; do
			local j="${f%.pcap}.json"
			if ! [ -f "$j" ]; then
				run scetrace -r \"$f\" \> \"$j\"
			fi
		done
		shopt -u nullglob
	esac
}

compress() {
	local dir="$1"

	case $PHASE in
	process)
		if type parallel &> /dev/null; then
			parallel bzip2 -9 ::: $dir/*.pcap $dir/*.debug.log
		else
			bzip2 -9 $dir/*.pcap $dir/*.debug.log
		fi
	esac
}

htb_qdisc() {
	local ifaces="$1"; shift
	local rate=$1; shift
	local p="$@"

	for i in $(split $ifaces); do
		case $PHASE in
		setup)
			run tc qdisc add dev $i root handle 1: htb default 1 || return
			run tc class add dev $i parent 1: classid 1:1 htb rate $rate ceil $rate || return
			run tc qdisc add dev $i parent 1:1 $p || return
			;;
		init|teardown)
			runq tc qdisc del dev $i root || true
			;;
		show*)
			run tc -s -d qdisc show dev $i
			run tc -s -d class show dev $i
			;;
		esac
	done
}

root_qdisc() {
	local ifaces="$1"; shift
	local p="$@"

	for i in $(split $ifaces); do
		case $PHASE in
		setup)
			run tc qdisc add dev $i root handle 1: $p || return
			;;
		init|teardown)
			runq tc qdisc del dev $i root || true
			;;
		show*)
			run tc -s -d qdisc show dev $i
			;;
		esac
	done
}

netem() {
	local ifaces="$1"; shift
	local p="$@"

	for i in $(split $ifaces); do
		case $PHASE in
		setup)
			modprobe ifb || return
			runq ip link add dev $(ifb $i) type ifb || return
			runq tc qdisc add dev $(ifb $i) root handle 1: netem $p || return
	
			runq tc qdisc add dev $i handle ffff: ingress || return
			runq ip link set $(ifb $i) up || return
			runq tc filter add dev $i parent ffff: protocol all prio 10 u32 match u32 0 0 \
				flowid 1:1 action mirred egress redirect dev $(ifb $i) || return
			;;
		init|teardown)
			runq tc qdisc del dev $i ingress || true
			runq tc qdisc del dev $(ifb $i) root || true
			runq ip link del dev $(ifb $i) || true
			;;
		show*)
			run tc -s -d qdisc show dev $(ifb $i)
			;;
		esac
	done
}

set_tos() {
	local ifaces="$1"; shift
	local tos="$1"
	local args="-o $i -p tcp -m tcp ! --syn -j TOS --set-tos $tos"

	for i in $(split $ifaces); do
		case $PHASE in
		setup)
			runq iptables -t mangle -I POSTROUTING $args || return
			;;
		init|teardown)
			runq iptables -t mangle -D POSTROUTING $args || true
			;;
		show*)
			run iptables -t mangle -L POSTROUTING -n || return
			;;
		esac
	done
}

dscp_to_tos() {
	local ifaces="$1"; shift
	local dscp="$1"; shift
	local tos="$1"; shift
	local args="-o $i -p tcp -m tcp ! --syn -m dscp --dscp $dscp -j TOS --set-tos $tos"

	for i in $(split $ifaces); do
		case $PHASE in
		setup)
			runq iptables -t mangle -I POSTROUTING $args || return
			;;
		init|teardown)
			runq iptables -t mangle -D POSTROUTING $args || true
			;;
		show*)
			run iptables -t mangle -L POSTROUTING -n || return
			;;
		esac
	done
}

ifb() {
	local iface=$1
	echo "ifb4$iface"
}

run() {
	echo "+ $@"
	eval "$@"
	echo
}

runq() {
	if [ $DEBUG == 1 ]; then
		echo "+ $@"
	fi
	eval "$@" &>/dev/null
}

split() {
	local s=(${1//,/ })
	echo "${s[@]}"
}

eval "$@" || exit 1

exit 0
