function batteryPercentage(device) {
  if (!device || !device.isPresent) return -1
  return Math.round(Number(device.percentage || 0) * 100)
}

function isDischarging(device, onBattery, dischargingState) {
  return !!(device && device.isPresent && onBattery && device.state === dischargingState)
}

// warningMayShow: a warning may still be on screen, sent by this service or
// restored after a shell restart, and no dismissal has been acknowledged since.
// The dismissal needs a device UPower has read (`ready`): right after a shell
// start the display device holds defaults, which look like a battery that is
// gone or not discharging. It reads the device's own state, not onBattery.
function shouldWarnLowBattery(device, onBattery, dischargingState, threshold, alreadyNotified, warningMayShow) {
  if (!device || !device.ready) return { level: -1, notify: false, dismiss: false, notifiedLowBattery: !!alreadyNotified }

  var level = batteryPercentage(device)
  if (level < 0) return { level: level, notify: false, dismiss: !!warningMayShow, notifiedLowBattery: false }

  var low = isDischarging(device, onBattery, dischargingState) && level <= threshold
  var recovered = device.state !== dischargingState || level > threshold
  return {
    level: level,
    notify: low && !alreadyNotified,
    dismiss: recovered && !!warningMayShow,
    notifiedLowBattery: low
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    batteryPercentage: batteryPercentage,
    isDischarging: isDischarging,
    shouldWarnLowBattery: shouldWarnLowBattery
  }
}
