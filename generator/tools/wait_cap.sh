#!/bin/bash
# retry run_cap.sh until no YataiDON process is running (other agents / user), max ~10 min
for i in $(seq 1 60); do
  if ! tasklist 2>/dev/null | grep -qi "yataidon"; then
    /d/YataiDON_agents/simplestyle/run_cap.sh "$@"; rc=$?
    [ $rc -ne 2 ] && exit $rc
  fi
  sleep 10
done
echo "gave up waiting"; exit 2
