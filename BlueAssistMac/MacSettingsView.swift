import Foundation
import Combine
import SwiftUI
import AppKit
import IOBluetooth

enum BluetoothDoctorSettings {
    static let autoScanEnabled = "Auto_scan_enabled"
    static let signalWarningThreshold = "Signal_warning_threshold"
    static let showAdvancedEvidence = "Show_advanced_evidence"
    static let scanDuration = "Scan_duration"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            autoScanEnabled: true,
            signalWarningThreshold: -85,
            showAdvancedEvidence: true,
            scanDuration: 10
        ])
    }
}

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

// MARK: - Glass helpers for the paired-device detail screen

private struct MacGlassBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            RadialGradient(
                colors: [.blue.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 120,
                endRadius: 560
            )

            RadialGradient(
                colors: [.cyan.opacity(0.10), .clear],
                center: .bottomLeading,
                startRadius: 80,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

private extension View {
    func macGlassPanel(cornerRadius: CGFloat = 24, padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
    }

    func macGlassControl(prominent: Bool = false) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                prominent ? Color.blue.opacity(0.92) : Color.secondary.opacity(0.20),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(.white.opacity(prominent ? 0.20 : 0.10), lineWidth: 1)
            }
    }
}

private struct MacInfoLine: View {
    let title: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Text(value)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

private struct MacStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.13), in: Capsule())
            .overlay {
                Capsule().stroke(tint.opacity(0.24), lineWidth: 1)
            }
    }
}

// MARK: - Models

struct MacSystemBluetoothDevice: Identifiable {
    let id: String
    let name: String
    let address: String
    let isPaired: Bool
    let isConnected: Bool
    let device: IOBluetoothDevice

    var likelySystemManaged: Bool {
        let lowered = name.lowercased()
        let markers = [
            "airpods", "beats", "find my", "magic mouse", "magic keyboard",
            "magic trackpad", "keyboard", "mouse", "trackpad", "speaker",
            "headphone", "headset", "audio", "buds", "earbuds"
        ]

        return markers.contains { lowered.contains($0) }
    }

    var typeHint: String {
        if likelySystemManaged {
            return "Likely system-managed accessory"
        }

        return "Paired Bluetooth device"
    }
}

// MARK: - Paired Mac device detail

struct MacSystemBluetoothDeviceDetailView: View {
    let device: MacSystemBluetoothDevice
    @ObservedObject var manager: MacSystemBluetoothManager

    @AppStorage(BluetoothDoctorSettings.showAdvancedEvidence)
    private var showAdvancedEvidence = true

    private var diagnosis: MacDeviceDiagnosis {
        diagnoseMacSystemDevice(device, manager: manager)
    }

    private var connectedColor: Color {
        device.isConnected ? .green : .red
    }

    private var pairedColor: Color {
        device.isPaired ? .green : .red
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                MacDiagnosisGlassCard(diagnosis: diagnosis, showsEvidence: showAdvancedEvidence)
                actionsCard

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    deviceInfoCard
                    statusCard
                }

                noteCard
            }
            .padding(24)
        }
        .background(MacGlassBackground())
        .navigationTitle(device.name)
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: device.likelySystemManaged ? "sparkles.rectangle.stack" : "antenna.radiowaves.left.and.right")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(device.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))

                    MacStatusPill(
                        text: device.isConnected ? "Connected" : "Not connected",
                        tint: connectedColor
                    )
                }

                Text(device.typeHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(device.address)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            if device.likelySystemManaged {
                VStack(alignment: .trailing, spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.title2)
                        .foregroundStyle(.yellow)

                    Text("MacOS controls\nnormal connection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .macGlassPanel(cornerRadius: 28, padding: 22)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("actions")
                .font(.headline)

            HStack(spacing: 12) {
                if device.isConnected {
                    Button {
                        manager.disconnect(device)
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .macGlassControl(prominent: true)
                } else {
                    Button {
                        manager.openBluetoothSettings()
                    } label: {
                        Label("Open bluetooth settings", systemImage: "gearshape.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .macGlassControl(prominent: true)

                    Button {
                        manager.requestLowLevelConnection(device)
                    } label: {
                        Label("Send low-level request", systemImage: "bolt.horizontal")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .macGlassControl()
                }

                Button {
                    manager.loadPairedDevices()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .macGlassControl()
            }

            Text("Opening Bluetooth Settings is the normal connection path. The low-level request is best-effort and may not work for AirPods, audio devices, keyboards, mice, Find My, or other system-managed accessories.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .macGlassPanel(cornerRadius: 22)
    }

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("device info")
                .font(.headline)

            MacInfoLine(title: "Name", value: device.name)
            MacInfoLine(title: "Address", value: device.address)
            MacInfoLine(title: "Paired", value: device.isPaired ? "Yes" : "No", valueColor: pairedColor)
            MacInfoLine(title: "System status", value: device.isConnected ? "Connected" : "Not connected", valueColor: connectedColor)
            MacInfoLine(title: "Connection type", value: device.likelySystemManaged ? "macOS-managed" : "standard paired device", valueColor: device.likelySystemManaged ? .yellow : .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .macGlassPanel(cornerRadius: 22)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest BlueAssistMac action")
                .font(.headline)

            Text(manager.statusMessage(for: device))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = manager.errorMessage(for: device) {
                Divider()

                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .macGlassPanel(cornerRadius: 22)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Why BlueAssistMac cannot always connect it directly", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)

            Text("BlueAssistMac can request a low-level Bluetooth link, but macOS owns normal profile connections such as audio output, keyboard/mouse input, AirPods, Find My, and some Apple-managed accessories. For those devices, Bluetooth Settings is the reliable path.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .macGlassPanel(cornerRadius: 22)
    }
}

private struct MacDiagnosisGlassCard: View {
    let diagnosis: MacDeviceDiagnosis
    let showsEvidence: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(diagnosis.severity.tint.opacity(0.18))
                        .frame(width: 72, height: 72)

                    Image(systemName: diagnosis.severity.iconName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(diagnosis.severity.tint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mac Bluetooth Diagnosis")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(diagnosis.reason)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(diagnosis.severity.label)
                        .font(.subheadline.bold())
                        .foregroundStyle(diagnosis.severity.tint)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 7) {
                    Text("\(Int(diagnosis.confidence * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ProgressView(value: diagnosis.confidence)
                        .frame(width: 150)
                        .tint(diagnosis.severity.tint)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("what to do next")
                    .font(.headline)

                Text(diagnosis.fix)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsEvidence, !diagnosis.evidence.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("What BlueAssistMac observed")
                        .font(.headline)

                    ForEach(diagnosis.evidence, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.cyan)

                            Text(item)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .macGlassPanel(cornerRadius: 30, padding: 24)
    }
}

// MARK: - Manager

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

    /// Best-effort only. This can create a low-level Bluetooth link for some devices,
    /// but it cannot force macOS profile connections such as AirPods/audio/HID/Find My.
    func requestLowLevelConnection(_ item: MacSystemBluetoothDevice) {
        clearError(for: item)

        if item.likelySystemManaged {
            setStatus("This looks system-managed. Opening Bluetooth Settings is recommended; trying a low-level request anyway...", for: item)
        } else {
            setStatus("Sending a low-level Bluetooth connection request to \(item.name)...", for: item)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = item.device.openConnection()

            DispatchQueue.main.async {
                if result == kIOReturnSuccess {
                    self.setStatus("Low-level connection request finished for \(item.name). Waiting for macOS to update the device state...", for: item)
                } else {
                    let message = self.bluetoothErrorMessage(result)
                    self.setStatus("Low-level connection request failed for \(item.name).", for: item)
                    self.setError(message, for: item)
                }

                self.refreshDeviceLater(item)
            }
        }
    }

    /// Backwards-compatible wrapper in case older code still calls `connect(_:)`.
    func connect(_ item: MacSystemBluetoothDevice) {
        requestLowLevelConnection(item)
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
            setStatus("macOS now reports \(updatedDevice.name) as connected.", for: item)
            clearError(for: item)
        } else {
            if errorMessage(for: item) == nil {
                if updatedDevice.likelySystemManaged {
                    setError("macOS did not report this device as connected after the low-level request. This device is likely controlled by Bluetooth Settings, Sound Output, Find My, or a system profile.", for: item)
                } else {
                    setError("macOS did not report this device as connected after the low-level request. It may be asleep, out of range, already connected elsewhere, or using a profile BlueAssistMac cannot control.", for: item)
                }
            }

            setStatus("Low-level request finished, but \(updatedDevice.name) is still not connected.", for: item)
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
            return "This Bluetooth device does not support this type of low-level connection through BlueAssistMac."

        default:
            return "Bluetooth connection failed with error code: \(result). The device may require Bluetooth Settings or a system-managed profile."
        }
    }

    func openBluetoothSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.BluetoothSettings",
            "x-apple.systempreferences:com.apple.preference.bluetooth"
        ]

        for rawURL in urls {
            if let url = URL(string: rawURL) {
                NSWorkspace.shared.open(url)
                return
            }
        }

        if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences"
        ) {
            NSWorkspace.shared.open(appURL)
        }
    }

    func disconnect(_ item: MacSystemBluetoothDevice) {
        setStatus("Disconnecting \(item.name)...", for: item)

        DispatchQueue.global(qos: .userInitiated).async {
            item.device.closeConnection()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.loadPairedDevices()

                if let updatedDevice = self.pairedDevices.first(where: { $0.id == item.id }) {
                    if updatedDevice.isConnected {
                        self.setStatus("Disconnect request sent, but \(updatedDevice.name) still appears connected.", for: item)
                        self.setError("macOS still reports this device as connected. It may be controlled by a system audio/profile service.", for: item)
                    } else {
                        self.setStatus("macOS now reports \(updatedDevice.name) as disconnected.", for: item)
                        self.clearError(for: item)
                    }
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
        statusText = message
    }

    private func setError(_ message: String, for device: MacSystemBluetoothDevice) {
        deviceErrorMessages[device.id] = message
    }

    func clearError(for device: MacSystemBluetoothDevice) {
        deviceErrorMessages[device.id] = nil
    }
}

// MARK: - Diagnosis

struct MacDeviceDiagnosis {
    let reason: String
    let confidence: Double
    let severity: DiagnosticSeverity
    let evidence: [String]
    let fix: String
}

func diagnoseMacSystemDevice(
    _ device: MacSystemBluetoothDevice,
    manager: MacSystemBluetoothManager
) -> MacDeviceDiagnosis {
    let actionStatus = manager.statusMessage(for: device)
    let actionEvidence = actionStatus == "No action taken yet."
        ? []
        : ["Last BlueAssistMac action: \(actionStatus)"]

    if device.isConnected {
        return MacDeviceDiagnosis(
            reason: "Device is already connected",
            confidence: 1.0,
            severity: .healthy,
            evidence: [
                "macOS reports this device as connected",
                "Device is paired with this Mac"
            ] + actionEvidence,
            fix: "No Bluetooth connection action is needed. If audio is not playing through this device, check Sound Output because macOS controls audio routing."
        )
    }

    if let errorMessage = manager.errorMessage(for: device) {
        let loweredError = errorMessage.lowercased()

        if loweredError.contains("not permitted") || loweredError.contains("permission") {
            return MacDeviceDiagnosis(
                reason: "Bluetooth permission blocked the request",
                confidence: 0.95,
                severity: .issue,
                evidence: [
                    "macOS returned: \(errorMessage)",
                    "Device is paired but not connected"
                ] + actionEvidence,
                fix: "Enable Bluetooth permission for BlueAssistMac in System Settings → Privacy & Security → Bluetooth, then try again."
            )
        }

        if loweredError.contains("timed out") || loweredError.contains("timeout") {
            return MacDeviceDiagnosis(
                reason: "Low-level request timed out",
                confidence: 0.85,
                severity: .issue,
                evidence: [
                    "macOS returned: \(errorMessage)",
                    "Device is paired but not connected"
                ] + actionEvidence,
                fix: "Move the device closer, wake it, charge it if needed, and make sure it is not connected elsewhere. For AirPods, audio, keyboard, mouse, Find My, or system-managed accessories, open Bluetooth Settings to connect normally."
            )
        }

        if loweredError.contains("busy") || loweredError.contains("already") {
            return MacDeviceDiagnosis(
                reason: "Bluetooth device or controller is busy",
                confidence: 0.8,
                severity: .warning,
                evidence: [
                    "macOS returned: \(errorMessage)",
                    "Device is paired but not connected"
                ] + actionEvidence,
                fix: "Wait a few seconds, disconnect the device from other hosts, then refresh. If this is a profile-controlled accessory, use Bluetooth Settings."
            )
        }

        if loweredError.contains("not found") || loweredError.contains("no longer paired") {
            return MacDeviceDiagnosis(
                reason: "Paired device is not reachable",
                confidence: 0.85,
                severity: .issue,
                evidence: [
                    "macOS returned: \(errorMessage)",
                    "Device is paired but not connected"
                ] + actionEvidence,
                fix: "Turn the device on, move it near the Mac, and open Bluetooth Settings if macOS no longer lists it reliably."
            )
        }

        if loweredError.contains("unsupported") || loweredError.contains("system-managed") || loweredError.contains("profile") {
            return MacDeviceDiagnosis(
                reason: "Normal connection is controlled by macOS",
                confidence: 0.85,
                severity: .warning,
                evidence: [
                    "macOS returned: \(errorMessage)",
                    "Device is paired but not connected"
                ] + actionEvidence,
                fix: "Open Bluetooth Settings to connect this device normally. BlueAssistMac can send a low-level request, but macOS controls audio, HID, AirPods, Find My, and other system-managed profiles."
            )
        }

        return MacDeviceDiagnosis(
            reason: "Low-level connection request failed",
            confidence: 0.7,
            severity: .issue,
            evidence: [
                "macOS returned: \(errorMessage)",
                "Device is paired but not connected"
            ] + actionEvidence,
            fix: "Refresh, wake the device, move it closer, disconnect it from other hosts, then use Bluetooth Settings if your goal is the normal macOS connection."
        )
    }

    if device.isPaired && !device.isConnected && device.likelySystemManaged {
        return MacDeviceDiagnosis(
            reason: "Normal connection is controlled by macOS",
            confidence: 0.9,
            severity: .warning,
            evidence: [
                "macOS remembers this device",
                "Device is currently not connected",
                "Device name suggests a system-managed accessory"
            ] + actionEvidence,
            fix: "Open Bluetooth Settings to connect this device normally. BlueAssistMac can only send a low-level request; it cannot force AirPods, Find My, audio, keyboard, mouse, or other macOS-managed profile connections."
        )
    }

    if device.isPaired && !device.isConnected {
        return MacDeviceDiagnosis(
            reason: "Device is paired but not connected",
            confidence: 0.85,
            severity: .warning,
            evidence: [
                "macOS remembers this device",
                "Device is currently not connected"
            ] + actionEvidence,
            fix: "Open Bluetooth Settings to connect it normally, or try Send Low-Level Request as a best-effort check. If it still fails, the device may be asleep, out of range, or using a profile BlueAssistMac cannot control."
        )
    }

    if !device.isPaired {
        return MacDeviceDiagnosis(
            reason: "Device is not paired",
            confidence: 0.9,
            severity: .issue,
            evidence: [
                "macOS does not report this as a paired device"
            ] + actionEvidence,
            fix: "Open Bluetooth Settings and pair the device first."
        )
    }

    return MacDeviceDiagnosis(
        reason: "Exact cause could not be determined",
        confidence: 0.3,
        severity: .unknown,
        evidence: [
            "macOS did not expose enough information"
        ] + actionEvidence,
        fix: "Open Bluetooth Settings, put the device in pairing mode, and try connecting again."
    )
}

struct DeviceMotionAnalysis {
    let device: BluetoothDevice
    var samples: [Int]
}

