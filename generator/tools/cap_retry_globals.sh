#!/bin/bash
# retry run_cap.sh while another agent's run is active (never kills anything)
for i in $(seq 1 60); do
  out=$(cd /d/YataiDON_agents/simplestyle && ./run_cap.sh "$@" 2>&1)
  if echo "$out" | grep -q "not starting"; then sleep $((3 + RANDOM % 6)); else echo "$out" | grep -v "Music\|Sounds\|RtAudio"; exit 0; fi
done
echo "gave up"; exit 3
