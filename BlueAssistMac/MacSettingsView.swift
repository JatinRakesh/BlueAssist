//
//  MacSettingsView.swift
//  BlueAssistMac
//
//  Created by Jatin Rakesh on 7/5/26.
//

import Foundation
import Combine
enum BluetoothDoctorSettings {
    static let autoScanEnabled = "auto_scan_enabled"
    static let signalWarningThreshold = "signal_warning_threshold"
    static let showAdvancedEvidence = "show_advanced_evidence"
    static let scanDuration = "scan_duration"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            autoScanEnabled: true,
            signalWarningThreshold: -85,
            showAdvancedEvidence: true,
            scanDuration: 10
        ])
    }
}
import Foundation
import SwiftUI

struct MacSettingsView: View {
    @AppStorage(BluetoothDoctorSettings.autoScanEnabled)
    private var autoScanEnabled = true

    @AppStorage(BluetoothDoctorSettings.signalWarningThreshold)
    private var signalWarningThreshold = -85

    @AppStorage(BluetoothDoctorSettings.showAdvancedEvidence)
    private var showAdvancedEvidence = true

    @AppStorage(BluetoothDoctorSettings.scanDuration)
    private var scanDuration = 10

    var body: some View {
        TabView {
            Form {
                Toggle("Auto Scan Nearby Devices", isOn: $autoScanEnabled)

                Stepper(
                    "Signal Warning Threshold: \(signalWarningThreshold) dBm",
                    value: $signalWarningThreshold,
                    in: -100 ... -40
                )

                Stepper(
                    "Scan Duration: \(scanDuration) seconds",
                    value: $scanDuration,
                    in: 3 ... 60
                )
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }

            Form {
                Toggle("Show Advanced Evidence", isOn: $showAdvancedEvidence)

                Text("Advanced evidence shows RSSI, advertising state, connection errors, and battery service availability.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .tabItem {
                Label("Diagnostics", systemImage: "waveform.path.ecg")
            }
        }
        .frame(width: 480, height: 260)
    }
}

import IOBluetooth

struct MacSystemBluetoothDevice: Identifiable {
    let id: String
    let name: String
    let address: String
    let isPaired: Bool
    let isConnected: Bool
    let device: IOBluetoothDevice
}
struct MacSystemBluetoothDeviceDetailView: View {
    let device: MacSystemBluetoothDevice
    @ObservedObject var manager: MacSystemBluetoothManager

    var diagnosis: MacDeviceDiagnosis {
        diagnoseMacSystemDevice(device)
    }

    var connectedColor: Color {
        device.isConnected ? .green : .red
    }

    var pairedColor: Color {
        device.isPaired ? .green : .red
    }

    var body: some View {
        List {
            Section("Device") {
                LabeledContent("Name", value: device.name)
                LabeledContent("Address", value: device.address)

                HStack {
                    Text("Paired")
                    Spacer()
                    Text(device.isPaired ? "Yes" : "No")
                        .foregroundStyle(pairedColor)
                }

                HStack {
                    Text("Connected")
                    Spacer()
                    Text(device.isConnected ? "Yes" : "No")
                        .foregroundStyle(connectedColor)
                }
            }

            Section("Diagnosis") {
                LabeledContent("Reason", value: diagnosis.reason)
                LabeledContent("Confidence", value: "\(Int(diagnosis.confidence * 100))%")

                Text(diagnosis.fix)
                    .foregroundStyle(.secondary)

                ForEach(diagnosis.evidence, id: \.self) { item in
                    Text("• \(item)")
                        .font(.caption)
                }
            }

            Section("Actions") {
                if device.isConnected {
                    Button("Disconnect") {
                        manager.disconnect(device)
                    }
                } else {
                    Button("Connect to the device") {
                        manager.connect(device)
                    }
                }

                Button("Refresh") {
                    manager.loadPairedDevices()
                }
            }

            Section("Status") {
                Text(manager.statusText)
                    .foregroundStyle(.secondary)
            }

            Section("Note") {
                Text("Some audio devices, AirPods, and Apple-managed accessories may still require macOS Bluetooth Settings because their audio/profile connection is controlled by the system.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(device.name)
    }
}

final class MacSystemBluetoothManager: NSObject, ObservableObject {
    @Published var pairedDevices: [MacSystemBluetoothDevice] = []
    @Published var statusText: String = "Loading paired Bluetooth devices..."
    @Published var deviceStatusMessages: [String: String] = [:]
    @Published var deviceErrorMessages: [String: String] = [:]

    override init() {
        super.init()
        loadPairedDevices()
    }

    func loadPairedDevices() {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            statusText = "Could not load paired Bluetooth devices."
            return
        }

        pairedDevices = devices.compactMap { device in
            let name = device.name ?? device.addressString ?? "Unknown Device"
            let address = device.addressString ?? UUID().uuidString

            return MacSystemBluetoothDevice(
                id: address,
                name: name,
                address: address,
                isPaired: device.isPaired(),
                isConnected: device.isConnected(),
                device: device
            )
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        statusText = "Found \(pairedDevices.count) paired Mac Bluetooth devices."
    }

    func connect(_ item: MacSystemBluetoothDevice) {
        setStatus("Connecting to \(item.name)...", for: item)

        let result = item.device.openConnection()

        if result == kIOReturnSuccess {
            setStatus("Connection request sent to \(item.name). Waiting for macOS to update...", for: item)

            /*
             Do NOT clear the error immediately.
             Only clear it after we confirm the device is connected.
            */
        } else {
            let message = bluetoothErrorMessage(result)
            setStatus("Could not connect to \(item.name).", for: item)
            setError(message, for: item)
        }

        refreshDeviceLater(item)
    }
    private func refreshDeviceLater(_ item: MacSystemBluetoothDevice) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadPairedDevices()
            self.updateConnectionResult(for: item)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.loadPairedDevices()
            self.updateConnectionResult(for: item)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.loadPairedDevices()
            self.updateConnectionResult(for: item)
        }
    }
    private func updateConnectionResult(for item: MacSystemBluetoothDevice) {
        guard let updatedDevice = pairedDevices.first(where: { $0.id == item.id }) else {
            setStatus("Device no longer appears in paired Bluetooth devices.", for: item)
            setError("macOS no longer reports this device in the paired device list.", for: item)
            return
        }

        if updatedDevice.isConnected {
            setStatus("Connected to \(updatedDevice.name).", for: item)
            clearError(for: item)
        } else {
            if errorMessage(for: item) == nil {
                setError(
                    "macOS did not report this device as connected after the connection request. This device may require Bluetooth Settings, may be asleep, out of range, already connected elsewhere, or controlled by an audio/profile service.",
                    for: item
                )
            }

            setStatus("Connection request finished, but \(updatedDevice.name) is still not connected.", for: item)
        }
    }
    private func bluetoothErrorMessage(_ result: IOReturn) -> String {
        switch result {
        case kIOReturnSuccess:
            return "No error."

        case kIOReturnNotPermitted:
            return "Bluetooth access was not permitted. Check System Settings → Privacy & Security → Bluetooth."

        case kIOReturnNotFound:
            return "The Bluetooth device was not found. It may be off, asleep, out of range, or no longer paired."

        case kIOReturnNotOpen:
            return "The Bluetooth device connection is not open."

        case kIOReturnNoDevice:
            return "No Bluetooth device was available for this connection."

        case kIOReturnBusy:
            return "The Bluetooth device or Bluetooth controller is busy. It may already be connecting or connected elsewhere."

        case kIOReturnTimeout:
            return "The connection timed out. The device may be too far away, asleep, low battery, or connected to another device."

        case kIOReturnUnsupported:
            return "This Bluetooth device does not support this type of connection through BlueAssist."

        default:
            return "Bluetooth connection failed with error code: \(result). The device may require macOS Bluetooth Settings or a system-managed profile."
        }
    }
    func disconnect(_ item: MacSystemBluetoothDevice) {
        setStatus("Disconnecting from \(item.name)...", for: item)

        item.device.closeConnection()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadPairedDevices()

            if let updatedDevice = self.pairedDevices.first(where: { $0.id == item.id }) {
                if updatedDevice.isConnected {
                    self.setStatus("Disconnect request sent, but \(updatedDevice.name) still appears connected.", for: item)
                    self.setError("macOS still reports this device as connected after disconnect. It may be controlled by a system audio/profile service.", for: item)
                } else {
                    self.setStatus("Disconnected from \(updatedDevice.name).", for: item)
                    self.clearError(for: item)
                }
            }
        }
    }
    
    func statusMessage(for device: MacSystemBluetoothDevice) -> String {
        deviceStatusMessages[device.id] ?? "No action taken yet."
    }

    func errorMessage(for device: MacSystemBluetoothDevice) -> String? {
        deviceErrorMessages[device.id]
    }

    private func setStatus(_ message: String, for device: MacSystemBluetoothDevice) {
        deviceStatusMessages[device.id] = message
    }

    private func setError(_ message: String, for device: MacSystemBluetoothDevice) {
        deviceErrorMessages[device.id] = message
    }

    func clearError(for device: MacSystemBluetoothDevice) {
        deviceErrorMessages[device.id] = nil
    }
}
struct MacDeviceDiagnosis {
    let reason: String
    let confidence: Double
    let evidence: [String]
    let fix: String
}
func diagnoseMacSystemDevice(_ device: MacSystemBluetoothDevice) -> MacDeviceDiagnosis {
    if device.isConnected {
        return MacDeviceDiagnosis(
            reason: "Device is already connected",
            confidence: 1.0,
            evidence: [
                "macOS reports this device as connected",
                "Device is paired with this Mac"
            ],
            fix: "No action needed. If audio is not playing through it, check Sound Output settings."
        )
    }

    if device.isPaired && !device.isConnected {
        return MacDeviceDiagnosis(
            reason: "Device is paired but not connected",
            confidence: 0.85,
            evidence: [
                "macOS remembers this device",
                "Device is currently not connected"
            ],
            fix: "Try Connect Like Mac Bluetooth. If it fails, make sure the device is awake, charged, nearby, and not connected to another phone or computer."
        )
    }

    if !device.isPaired {
        return MacDeviceDiagnosis(
            reason: "Device is not paired",
            confidence: 0.9,
            evidence: [
                "macOS does not report this as a paired device"
            ],
            fix: "Open Bluetooth Settings and pair the device first."
        )
    }

    return MacDeviceDiagnosis(
        reason: "Exact cause could not be determined",
        confidence: 0.3,
        evidence: [
            "macOS did not expose enough information"
        ],
        fix: "Try opening Bluetooth Settings, putting the device in pairing mode, and connecting again."
    )
}
