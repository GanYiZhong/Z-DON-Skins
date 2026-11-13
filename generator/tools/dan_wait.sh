#!/bin/bash
# usage: tools/dan_wait.sh <command...>  : retries while another YataiDON process is running (max ~5 min)
for i in $(seq 1 100); do
  "$@"; rc=$?
  [ $rc -ne 2 ] && exit $rc
  sleep 3
done
exit 2
