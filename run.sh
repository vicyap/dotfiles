#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

BASEDIR=$(dirname "$BASE_SOURCE")
pushd "$BASEDIR"/scripts

source ./variables.sh

if [ "$1" == "check" ]; then
	source ./check.sh
fi

if [ "$1" == "install" ]; then
	source ./install.sh
fi

if [ "$1" == "deploy" ]; then
	source ./deploy.sh
fi

popd
