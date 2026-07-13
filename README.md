# McBlueAssist

McBlueAssist is a macOS Bluetooth diagnostic utility that helps users understand nearby Bluetooth Low Energy signals, paired Bluetooth devices, signal strength, and common Bluetooth connection issues.

McBlueAssist is designed to make Bluetooth troubleshooting clearer by showing what the app can observe, what the system controls, and what users can try next.

## What McBlueAssist Does

McBlueAssist can help you:

- scan nearby Bluetooth Low Energy devices
- view signal strength and RSSI values
- identify weak or unstable Bluetooth signals
- inspect public BLE services when available
- view paired Bluetooth devices known by the system
- understand why a device may not connect
- open Bluetooth Settings for system-managed devices
- explain when a device is controlled by system services rather than by third-party apps

## Important Note About Bluetooth Connections

Some devices, such as AirPods, Find My accessories, keyboards, mice, speakers, and other audio devices, are managed directly by system Bluetooth services.

McBlueAssist may not be able to fully connect those devices in the same way Bluetooth Settings can. Instead, McBlueAssist helps explain what is happening and guides users toward the correct next step.

For system-managed devices, users may need to connect through:

`System Settings → Bluetooth`

## Troubleshooting

### My device does not appear

Try the following:

- make sure Bluetooth is enabled
- move the device closer
- wake the device
- put the device into pairing mode
- disconnect the device from other phones, tablets, or computers
- restart Bluetooth if the device still does not appear

### My device appears but cannot be inspected

Some Bluetooth Low Energy devices do not expose public services to third-party apps. If McBlueAssist cannot inspect a device, the device may still work normally through Bluetooth Settings.

### My device is paired but not connected

Paired devices and nearby BLE signals are handled differently by the system. If a paired device does not connect through McBlueAssist, try connecting it from Bluetooth Settings.

### The app says battery is not exposed

Not every Bluetooth device exposes battery level through the standard Bluetooth Low Energy Battery Service. If battery information is unavailable, McBlueAssist will show it as not exposed.

## Optional Tips

McBlueAssist is free to use.

The app may include optional tips through Apple’s in-app purchase system. Tips are completely optional and do not unlock features or change app functionality.

Payment processing is handled by Apple. McBlueAssist does not receive or store payment card information.

## Privacy Policy

McBlueAssist does not collect, store, sell, or share personal information with the developer.

Bluetooth information shown in the app is processed locally on your device. This may include:

- nearby BLE device names, if advertised by the device
- Bluetooth signal strength / RSSI
- public BLE service information
- paired Bluetooth device names shown by the system
- diagnostic messages generated inside the app

This information is used only to display diagnostics inside the app and is not sent to the developer.

## Data Sharing

McBlueAssist does not sell user data.

McBlueAssist does not share Bluetooth diagnostic data with third parties.

## Children’s Privacy

McBlueAssist is not designed to collect personal information from children.

## Support

For support, feedback, bug reports, or privacy questions, contact:

-mcblueassist@gmail.com

When reporting an issue, please include:

- your macOS version
- the type of Bluetooth device you were trying to inspect
- whether the device appears in Bluetooth Settings
- what McBlueAssist showed on the diagnosis screen
- screenshots if helpful

## App Store Review Notes

McBlueAssist is a Bluetooth diagnostic utility. It does not replace Bluetooth Settings.

Some Bluetooth devices are controlled by system services, and McBlueAssist may direct users to Bluetooth Settings when normal system-level connection is required.

Optional tips do not unlock features.
