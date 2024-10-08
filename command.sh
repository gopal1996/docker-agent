#!/bin/sh
set -eu
export TINI_SUBREAPER=yes
/usr/local/bin/dockerd-entrypoint.sh &
/usr/local/bin/jenkins-agent "$@"