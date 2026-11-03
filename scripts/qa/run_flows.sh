#!/bin/zsh
# Runs Maestro flows on a simulator; every flow gets a video, Maestro's own
# detailed HTML report and one line in qa/reports/history.jsonl. The dashboard
# reads only that history and test output, so its numbers are real runs.
#   QA_CONFIG=yatay scripts/qa/run_flows.sh <udid> [flow.yaml ...]
set -u
cd "$(dirname "$0")/../.."
udid=$1; shift
flows=("$@")
[[ ${#flows[@]} -eq 0 ]] && flows=(.maestro/[0-9]*.yaml)
stamp=$(date +%Y-%m-%d_%H%M%S)
root=qa/artifacts/runs/$stamp
mkdir -p "$root" qa/reports
device=$(xcrun simctl list devices | grep "$udid" | sed -E 's/^ *(.*) \(.*\) \(.*$/\1/')
runtime=$(xcrun simctl list devices | awk -v u="$udid" '/^-- /{r=$2" "$3} index($0,u){print r}')
config=${QA_CONFIG:-}
fail=0
for flow in "${flows[@]}"; do
  name=${flow:t:r}
  out=$root/$name
  mkdir -p "$out"
  xcrun simctl io "$udid" recordVideo --codec=h264 --force "$out/video.mp4" >/dev/null 2>&1 &
  rec=$!
  print -r -- "{\"status\":\"RUNNING\",\"flow\":\"$name\",\"device\":\"$device\",\"started\":\"$(date -Iseconds)\"}" > qa/reports/current.json
  python3 -I scripts/qa/build_dashboard.py >/dev/null
  start=$SECONDS
  maestro --device "$udid" test --format html-detailed --output "$out/report.html" \
    --test-output-dir "$out" "$flow" > "$out/maestro.log" 2>&1
  code=$?
  kill -INT $rec 2>/dev/null; wait $rec 2>/dev/null
  result=PASS; (( code != 0 )) && { result=FAIL; fail=1; }
  print -r -- "{\"ts\":\"$stamp\",\"flow\":\"$name\",\"result\":\"$result\",\"seconds\":$((SECONDS-start)),\"device\":\"$device\",\"runtime\":\"$runtime\",\"config\":\"$config\",\"dir\":\"$out\"}" >> qa/reports/history.jsonl
  print -r -- "$result $name ($((SECONDS-start))s)"
  python3 -I scripts/qa/build_dashboard.py >/dev/null
done
print -r -- '{"status":"IDLE"}' > qa/reports/current.json
python3 -I scripts/qa/build_dashboard.py >/dev/null
exit $fail
