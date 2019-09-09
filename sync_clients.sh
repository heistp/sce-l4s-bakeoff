#!/bin/bash

usage() {
	echo "usage: $0 [push|pull] <dry>"
	exit 1
}

dry() {
	[ "$1" == "dry" ] && echo "n" || echo ""
}

if [ $# -lt 1 ]; then
	usage
fi

case $(hostname) in
c1)
	other=c2
	;;
c2)
	other=c1
	;;
*)
	echo "unknown hostname: $(hostname)"
	exit 1
	;;
esac

if [ $(basename $(pwd)) != "sce-l4s-bakeoff" ]; then
	echo "must be run from sce-l4s-bakeoff directory"
	exit 1
fi

case $1 in
push)
	src="./*"
	dst="pete@$other:~/src/sce-l4s-bakeoff"
	;;
pull)
	src="pete@$other:~/src/sce-l4s-bakeoff/*"
	dst=.
	;;
*)
	usage
	;;
esac

cmd="rsync -putv$(dry $2) $src $dst"
echo "+ $cmd"
$cmd
