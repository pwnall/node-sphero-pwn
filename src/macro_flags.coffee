# Maps developer-ffriendly flag names to value masks.
MacroFlags =
  brakeOnEnd: 0x01  # MF_MOTOR_CONTROL
  exclusiveDrive: 0x02  # MF_EXCLUSIVE_DRV
  stopOnDisconnect: 0x04  # MF_ALLOW_SOD
  inhibitIfConnected: 0x08  # MF_INH_IF_CONN
  markerOnEnd: 0x10  # MF_ENDSIG
  stealth: 0x20  # MF_STEALTH
  unkillable: 0x40  # MF_UNKILLABLE

module.exports = MacroFlags
