#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const battery = requireFromRoot('shell/plugins/services/battery/BatteryModel.js')
const discharging = 1
const charging = 2

assertEqual(battery.batteryPercentage({ isPresent: true, percentage: 0.126 }), 13, 'battery rounds display percentage')
assertEqual(battery.batteryPercentage({ isPresent: false, percentage: 0.5 }), -1, 'battery reports missing battery')
assert(battery.isDischarging({ isPresent: true, state: discharging }, true, discharging), 'battery detects discharging state')
assert(!battery.isDischarging({ isPresent: true, state: discharging }, false, discharging), 'battery requires on-battery state')

assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: true, isPresent: true, percentage: 0.08, state: discharging }, true, discharging, 10, false),
  { level: 8, notify: true, dismiss: false, notifiedLowBattery: true },
  'battery warns once under threshold'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: true, isPresent: true, percentage: 0.08, state: discharging }, true, discharging, 10, true, true),
  { level: 8, notify: false, dismiss: false, notifiedLowBattery: true },
  'battery keeps low-battery notified state'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: true, isPresent: true, percentage: 0.4, state: discharging }, true, discharging, 10, true, true),
  { level: 40, notify: false, dismiss: true, notifiedLowBattery: false },
  'battery clears notified state and dismisses the warning after recovery'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: true, isPresent: true, percentage: 0.08, state: charging }, false, discharging, 10, true, true),
  { level: 8, notify: false, dismiss: true, notifiedLowBattery: false },
  'battery dismisses the warning once the charger is plugged in'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: true, isPresent: true, percentage: 0.08, state: charging }, false, discharging, 10, false, true),
  { level: 8, notify: false, dismiss: true, notifiedLowBattery: false },
  'battery dismisses a warning restored after a shell restart'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: true, isPresent: true, percentage: 0.08, state: discharging }, true, discharging, 10, false, true),
  { level: 8, notify: true, dismiss: false, notifiedLowBattery: true },
  'battery warns again after a shell restart while still low'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: true, isPresent: true, percentage: 0.4, state: discharging }, true, discharging, 10, false, false),
  { level: 40, notify: false, dismiss: false, notifiedLowBattery: false },
  'battery sends no dismissal once one was acknowledged'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: true, isPresent: false }, false, discharging, 10, true, true),
  { level: -1, notify: false, dismiss: true, notifiedLowBattery: false },
  'battery dismisses the warning when the battery disappears'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: false, isPresent: false, percentage: 0, state: 0 }, false, discharging, 10, false, true),
  { level: -1, notify: false, dismiss: false, notifiedLowBattery: false },
  'battery keeps a restored warning until UPower has read the device'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: false, isPresent: false, percentage: 0, state: 0 }, false, discharging, 10, true, true),
  { level: -1, notify: false, dismiss: false, notifiedLowBattery: true },
  'battery keeps its notified state until UPower has read the device'
)
assertDeepEqual(
  battery.shouldWarnLowBattery({ ready: true, isPresent: true, percentage: 0.08, state: discharging }, false, discharging, 10, true, true),
  { level: 8, notify: false, dismiss: false, notifiedLowBattery: false },
  'battery keeps the warning while the device still reports discharging'
)
JS

service_qml="$ROOT/shell/plugins/services/battery/Service.qml"
summary_in_script=$(sed -n 's/.*-u critical "\([^"]*\)".*/\1/p' "$ROOT/bin/omarchy-battery-low")
summary_in_service=$(sed -n 's/.*warningSummary: "\([^"]*\)".*/\1/p' "$service_qml")
[[ -n $summary_in_script && $summary_in_script == "$summary_in_service" ]] || fail 'battery service dismisses the summary omarchy-battery-low sends'
pass 'battery service dismisses the summary omarchy-battery-low sends'

grep -q '"omarchy-shell", "notifications", "dismiss", warningSummary' "$service_qml" || fail 'battery service dismisses through omarchy-shell without -q'
grep -q 'exitCode === 0 && warningProcess.command\[0\] === "omarchy-shell") persisted.warningMayShow = false' "$service_qml" || fail 'battery service forgets the warning only when the shell takes the dismissal'
pass 'battery service forgets the warning only when the shell takes the dismissal'

grep -q 'function onReadyChanged() { root.checkBattery() }' "$service_qml" || fail 'battery service checks again once UPower has read the device'
grep -q 'function onStateChanged() { root.checkBattery() }' "$service_qml" || fail 'battery service checks again when the device state changes'
pass 'battery service checks again when the device is read or changes state'
