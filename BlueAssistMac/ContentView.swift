

import SwiftUI
import Foundation
import CoreBluetooth
import Combine
import AppKit

enum SidebarSelection: Hashable {
    case ble(UUID)
    case mac(String)
}
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    var filteredBLEDevices: [BluetoothDevice] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return bluetoothManager.devices
        }

        return bluetoothManager.devices.filter { device in
            bluetoothManager.displayName(for: device)
                .localizedCaseInsensitiveContains(query)
        }
    }

    var filteredMacDevices: [MacSystemBluetoothDevice] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return macBluetoothManager.pairedDevices
        }

        return macBluetoothManager.pairedDevices.filter { device in
            device.name.localizedCaseInsensitiveContains(query)
        }
    }

    @StateObject private var macBluetoothManager = MacSystemBluetoothManager()
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var showingFeedbackSheet = false
    @State private var searchText: String = ""
    @State private var selection: SidebarSelection?
    @State private var  showingFindMyDevice = false
    @State private var showingTipJar = false
    var selectedMacDevice: MacSystemBluetoothDevice? {
        guard case let .mac(id) = selection else { return nil }
        return macBluetoothManager.pairedDevices.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView {
            BlueAssistSidebar(
                bluetoothManager: bluetoothManager,
                macBluetoothManager: macBluetoothManager,
                macDevices: filteredMacDevices,
                bleDevices: filteredBLEDevices,
                selection: $selection
            )
            .searchable(text: $searchText, prompt: "Search devices")
            .navigationTitle("BlueAssist")
            .toolbar {
                Button {
                    if let url = URL(string: "https://forms.gle/UTcGBoxxdLGM6tMn7") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Feedback", systemImage: "bubble.left")
                }

                Button {
                    showingTipJar = true
                } label: {
                    Label("Support", systemImage: "heart.fill")
                }

                Button("Scan") {
                    bluetoothManager.startScanning()
                    macBluetoothManager.loadPairedDevices()
                }

                Button("Stop") {
                    bluetoothManager.stopScanning()
                }

                Button("Refresh Paired") {
                    macBluetoothManager.loadPairedDevices()
                }
            }
            .onChange(of: selection) { _, newSelection in
                switch newSelection {
                case .ble(let id):
                    if let device = bluetoothManager.devices.first(where: { $0.id == id }) {
                        bluetoothManager.selectDevice(device)
                    }

                case .mac:
                    bluetoothManager.selectedDevice = nil

                case .none:
                    bluetoothManager.selectedDevice = nil
                }
            }
        } detail: {            switch selection {
            case .ble:
                DeviceDetailView(
                    bluetoothManager: bluetoothManager,
                    macBluetoothManager: macBluetoothManager
                )

            case .mac:
                if let selectedMacDevice {
                    MacSystemBluetoothDeviceDetailView(
                        device: selectedMacDevice,
                        manager: macBluetoothManager
                    )
                } else {
                    Text("Select a paired Mac Bluetooth device.")
                        .foregroundStyle(.secondary)
                }
            case .none:
                StartDashboardView(
                    bluetoothManager: bluetoothManager,
                    macBluetoothManager: macBluetoothManager,
                    selection: $selection
                )
            }
        }
        
        .sheet(isPresented: $showingTipJar) {
            TipJarView()
        }
        .onAppear {
            bluetoothManager.startScanning()
            macBluetoothManager.loadPairedDevices()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                macBluetoothManager.loadPairedDevices()
                bluetoothManager.startScanning()
            }
        }
    }
}


struct DeviceDetailView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var macBluetoothManager: MacSystemBluetoothManager
    @AppStorage(BluetoothDoctorSettings.showAdvancedEvidence)
    private var showAdvancedEvidence = true
    @State private var nicknameText: String = ""

    var body: some View {
        if let device = bluetoothManager.selectedDevice {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let diagnosis = bluetoothManager.diagnosis {
                        DiagnosisSummaryView(
                            title: "BLE Diagnosis",
                            reason: diagnosis.reason.rawValue,
                            confidence: diagnosis.confidence,
                            severity: diagnosis.severity,
                            fix: diagnosis.fix,
                            evidence: diagnosis.evidence,
                            showsEvidence: showAdvancedEvidence
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Actions")
                            .font(.headline)

                        HStack(spacing: 12) {
                            if device.isConnectable {
                                Button {
                                    bluetoothManager.inspectSelectedBLEDevice()
                                } label: {
                                    Label("Inspect BLE data", systemImage: "waveform.path.ecg")
                                }
                                .buttonStyle(.plain)
                                .blueGlassControl(prominent: true)
                                Text("This does not pair the device or connect audio/keyboard profiles. It only opens a BLE inspection connection so BlueAssistMac can read public services.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    bluetoothManager.disconnect()
                                } label: {
                                    Label("Disconnect", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.plain)
                                .blueGlassControl()
                            } else {
                                Text("This device is not connectable through BlueAssistMac.")
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                bluetoothManager.startDiagnosisRun()
                                macBluetoothManager.loadPairedDevices()
                            } label: {
                                Label("Retry diagnosis", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .blueGlassControl()
                        }
                    }
                    .blueGlassPanel(cornerRadius: 22)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Device info")
                            .font(.headline)

                        InfoLine(
                            title: "Name",
                            value: bluetoothManager.displayName(for: device)
                        )

                        InfoLine(
                            title: "Identifier",
                            value: String(device.id.uuidString.prefix(8)) + "…"
                        )

                        InfoLine(
                            title: "Signal",
                            value: "\(device.signalLabel) · \(device.rssi) dBm",
                            valueColor: device.signalColor
                        )

                        InfoLine(
                            title: "Connectable",
                            value: device.connectableText,
                            valueColor: device.connectableColor
                        )

                        if let batteryLevel = bluetoothManager.batteryLevel {
                            InfoLine(
                                title: "Battery",
                                value: "\(batteryLevel)%"
                            )
                        } else {
                            InfoLine(
                                title: "Battery",
                                value: "Not exposed"
                            )
                        }
                    }
                    .blueGlassPanel(cornerRadius: 22)

                    DisclosureGroup("Advanced diagnostics") {
                        VStack(alignment: .leading, spacing: 10) {
                            InfoLine("RSSI", "\(device.rssi) dBm")
                            InfoLine("Signal quality", device.signalLabel)
                            InfoLine("Advertised services", device.advertisedServicesText)

                            if bluetoothManager.discoveredServices.isEmpty {
                                Text("Connect to the device to discover services.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(bluetoothManager.discoveredServices, id: \.self) { service in
                                    Text(service)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .blueGlassPanel(cornerRadius: 22)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nickname")
                            .font(.headline)

                        TextField("Custom name for this device", text: $nicknameText)

                        Button("Save nickname") {
                            bluetoothManager.saveNickname(nicknameText, for: device)
                        }

                        if let savedNickname = bluetoothManager.nickname(for: device) {
                            InfoLine("Saved name", savedNickname)
                        }
                    }
                    .blueGlassPanel(cornerRadius: 22)
                }
                .padding(24)
            }
            .background(BlueAssistBackground())
            .navigationTitle(bluetoothManager.displayName(for: device))
        } else {
            VStack(spacing: 12) {
                Text(bluetoothManager.statusText)
                    .font(.headline)

                Text("Select a nearby Bluetooth device to view signal, services, battery, and diagnosis.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button("Start Scan") {
                    bluetoothManager.startScanning()
                    macBluetoothManager.loadPairedDevices()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
extension InfoLine {
    init(_ title: String, _ value: String, valueColor: Color = .secondary) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
}
struct Diagnosis{
    let reason: FailureReason
    let confidence: Double
    let evidence: [String]
    let fix: String

    var severity: DiagnosticSeverity {
        switch reason {
        case .readyToScan, .readyToInspect, .goodSignalReadyToConnect:
            return .healthy
        case .connectedButLimitedData, .weakSignalMayFail, .noDiagnosticData:
            return .warning
        case .bluetoothOff, .permissionDenied, .deviceTooFar, .deviceBatteryLow,
             .deviceNotInPairingMode, .alreadyConnectedElsewhere, .stalePairingKeys,
             .deviceFirmwareIssue, .unsupportedDevice, .notConnectable:
            return .issue
        case .unknown:
            return .unknown
        }
    }
}
enum FailureReason: String {
    case readyToScan = "Bluetooth is on"
    case readyToInspect = "Device is ready to inspect"
    case connectedButLimitedData = "Connected but limited data available"
    case goodSignalReadyToConnect = "Good signal, ready to connect"
    case weakSignalMayFail = "Weak signal may cause connection failure"
    case bluetoothOff = "Bluetooth is turned off"
    case permissionDenied = "Bluetooth permission denied"
    case deviceTooFar = "Device is too far away or blocked"
    case deviceBatteryLow = "Device battery is low"
    case deviceNotInPairingMode = "Device is not in pairing mode"
    case alreadyConnectedElsewhere = "Device may be connected to another phone"
    case stalePairingKeys = "Pairing information is stale"
    case deviceFirmwareIssue = "Device firmware may be unresponsive"
    case unsupportedDevice = "This device does not expose enough Bluetooth data"
    case notConnectable = "Device is not connectable"
    case noDiagnosticData = "Device does not expose diagnostic data"
    case unknown = "Exact cause could not be determined"
}


func diagnoseConnectionFailure(
    bluetoothState: CBManagerState,
    lastRSSI: Int?,
    wasAdvertising: Bool,
    isConnectable: Bool?,
    hasAdvertisedServices: Bool?,
    connectionError: Error?,
    batteryLevel: Int?,
    disappearedDuringConnection: Bool
) -> Diagnosis {

    if bluetoothState == .unsupported {
        return Diagnosis(
            reason: .unsupportedDevice,
            confidence: 1.0,
            evidence: ["This Mac/app target does not support the required Bluetooth features"],
            fix: "Make sure you are running the native macOS target and Bluetooth permission is enabled."
        )
    }

    if bluetoothState == .resetting {
        return Diagnosis(
            reason: .unknown,
            confidence: 0.6,
            evidence: ["Bluetooth is resetting"],
            fix: "Wait a few seconds, then try again."
        )
    }

    if bluetoothState == .unknown {
        return Diagnosis(
            reason: .unknown,
            confidence: 0.4,
            evidence: ["Bluetooth state is not known yet"],
            fix: "Wait while BlueAssistMac checks Bluetooth status."
        )
    }

    if bluetoothState == .poweredOff {
        return Diagnosis(
            reason: .bluetoothOff,
            confidence: 1.0,
            evidence: ["Bluetooth state is powered off"],
            fix: "Turn on Bluetooth in macOS Control Center or System Settings."
        )
    }

    if bluetoothState == .unauthorized {
        return Diagnosis(
            reason: .permissionDenied,
            confidence: 1.0,
            evidence: ["BlueAssistMac does not have Bluetooth permission"],
            fix: "Enable Bluetooth permission in System Settings → Privacy & Security → Bluetooth."
        )
    }

    if let battery = batteryLevel, battery <= 10 {
        return Diagnosis(
            reason: .deviceBatteryLow,
            confidence: 0.95,
            evidence: ["Device battery is \(battery)%"],
            fix: "Charge the device, then try again."
        )
    }

    if let connectionError {
        var evidence = ["Connection error: \(connectionError.localizedDescription)"]

        if let rssi = lastRSSI {
            evidence.append("Last signal strength was \(rssi) dBm")
        }

        if let isConnectable {
            evidence.append(isConnectable ? "Device advertised as connectable" : "Device did not advertise as connectable")
        }

        return Diagnosis(
            reason: .deviceFirmwareIssue,
            confidence: 0.7,
            evidence: evidence,
            fix: "Wake or restart the device, move it closer, disconnect it from other computers or phones, then try Connect and Inspect again."
        )
    }

    if let isConnectable, isConnectable == false {
        return Diagnosis(
            reason: .notConnectable,
            confidence: 0.8,
            evidence: ["Device is advertising but marked as not connectable"],
            fix: "Put the device in pairing mode, wake it up, or choose a connectable device."
        )
    }

    if wasAdvertising && disappearedDuringConnection {
        return Diagnosis(
            reason: .alreadyConnectedElsewhere,
            confidence: 0.65,
            evidence: ["Device was visible, then disappeared during the connection attempt"],
            fix: "Disconnect it from other phones, tablets, or laptops, then try again."
        )
    }

    if let rssi = lastRSSI {
        if rssi < -90 {
            return Diagnosis(
                reason: .deviceTooFar,
                confidence: 0.9,
                evidence: ["Signal is extremely weak: \(rssi) dBm"],
                fix: "Move the device much closer to your Mac and remove obstacles."
            )
        }

        if rssi < -80 {
            return Diagnosis(
                reason: .weakSignalMayFail,
                confidence: 0.75,
                evidence: ["Signal is weak: \(rssi) dBm"],
                fix: "Move closer before connecting. Weak signal can cause timeouts or unstable connections."
            )
        }

        if rssi < -65 {
            return Diagnosis(
                reason: .weakSignalMayFail,
                confidence: 0.55,
                evidence: ["Signal is moderate/weak: \(rssi) dBm"],
                fix: "The device may connect, but moving closer will improve reliability."
            )
        }

        if let isConnectable, isConnectable == true {
            if let hasAdvertisedServices, hasAdvertisedServices == true {
                return Diagnosis(
                    reason: .readyToInspect,
                    confidence: 0.85,
                    evidence: [
                        "Device is connectable",
                        "Signal strength is usable: \(rssi) dBm",
                        "Device advertises BLE services"
                    ],
                    fix: "Click Connect and Inspect to discover services and check battery if the device exposes it."
                )
            }

            return Diagnosis(
                reason: .goodSignalReadyToConnect,
                confidence: 0.75,
                evidence: [
                    "Device is connectable",
                    "Signal strength is usable: \(rssi) dBm"
                ],
                fix: "Click Connect and Inspect. If no services appear, the device may not expose diagnostics to third-party apps."
            )
        }
    }

    if let hasAdvertisedServices, hasAdvertisedServices == false {
        return Diagnosis(
            reason: .noDiagnosticData,
            confidence: 0.6,
            evidence: ["No BLE services were advertised"],
            fix: "This device may not expose battery, firmware, or diagnostic data to third-party apps."
        )
    }

    if bluetoothState == .poweredOn,
       lastRSSI == nil,
       batteryLevel == nil,
       connectionError == nil {
        return Diagnosis(
            reason: .readyToScan,
            confidence: 1.0,
            evidence: ["Bluetooth is powered on"],
            fix: "Choose a nearby device to scan and diagnose."
        )
    }

    return Diagnosis(
        reason: .unknown,
        confidence: 0.35,
        evidence: ["BlueAssistMac does not yet have enough connection data"],
        fix: "Try Connect and Inspect, move closer, or check whether the device is already connected somewhere else."
    )
}


enum BlueAssistBluetoothError: LocalizedError {
    case connectionTimedOut

    var errorDescription: String? {
        switch self {
        case .connectionTimedOut:
            return "BlueAssistMac did not receive a BLE connection response after 12 seconds."
        }
    }
}
final class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var trackedRSSI: [UUID: [Int]] = [:]
    private var connectionTimeoutWorkItem: DispatchWorkItem?
    @Published var isFindingDevice = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var devices: [BluetoothDevice] = []
    @Published var selectedDevice: BluetoothDevice?
    @Published var statusText: String = "Checking Bluetooth..."
    @Published var connectedDeviceName: String?
    @Published var batteryLevel: Int?
    @Published var discoveredServices: [String] = []
    @Published var diagnosis: Diagnosis?

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?

    private let batteryServiceUUID = CBUUID(string: "180F")
    private let batteryLevelUUID = CBUUID(string: "2A19")

    override init() {
        super.init()

        centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    private func scheduleConnectionTimeout(for device: BluetoothDevice) {
        connectionTimeoutWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            if self.connectedPeripheral?.identifier == device.id {
                self.centralManager?.cancelPeripheralConnection(device.peripheral)
            }

            self.statusText = "\(self.displayName(for: device)) Did not respond to BLE inspection."

            self.diagnosis = diagnoseConnectionFailure(
                bluetoothState: self.bluetoothState,
                lastRSSI: device.rssi,
                wasAdvertising: true,
                isConnectable: device.isConnectable,
                hasAdvertisedServices: device.hasAdvertisedServices,
                connectionError: BlueAssistBluetoothError.connectionTimedOut,
                batteryLevel: self.batteryLevel,
                disappearedDuringConnection: false
            )
        }

        connectionTimeoutWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 12,
            execute: workItem
        )
    }
    private func cleanedName(_ value: String?) -> String? {
        guard let value else { return nil }

        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }
        guard cleaned.lowercased() != "unknown" else { return nil }
        guard cleaned.lowercased() != "unknown device" else { return nil }

        return cleaned
    }

    private func cachedNameKey(for id: UUID) -> String {
        "ble_real_name_\(id.uuidString)"
    }

    private func cachedName(for id: UUID) -> String? {
        cleanedName(UserDefaults.standard.string(forKey: cachedNameKey(for: id)))
    }

    private func saveCachedName(_ name: String, for id: UUID) {
        UserDefaults.standard.set(name, forKey: cachedNameKey(for: id))
    }
    func nicknameKey(for id: UUID) -> String {
        "Nickname_\(id.uuidString)"
    }

    func nickname(for device: BluetoothDevice) -> String? {
        UserDefaults.standard.string(forKey: nicknameKey(for: device.id))
    }

    func saveNickname(_ nickname: String, for device: BluetoothDevice) {
        UserDefaults.standard.set(nickname, forKey: nicknameKey(for: device.id))
        objectWillChange.send()
    }

    func displayName(for device: BluetoothDevice) -> String {
        if let nickname = nickname(for: device), !nickname.isEmpty {
            return nickname
        }

        return device.name
    }
    
    func findDevice(named searchText: String) {
        let cleanedSearch = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !cleanedSearch.isEmpty else {
            statusText = "Enter a device name to search."
            return
        }

        startScanning()

        let matchingDevices = devices.filter { device in
            let realName = device.name.lowercased()
            let savedNickname = nickname(for: device)?.lowercased() ?? ""

            return realName.contains(cleanedSearch) ||
                   savedNickname.contains(cleanedSearch) ||
                   cleanedSearch.contains(realName) ||
                   cleanedSearch.contains(savedNickname)
        }

        if let bestMatch = matchingDevices.sorted(by: { first, second in
            if first.isConnectable != second.isConnectable {
                return first.isConnectable && !second.isConnectable
            }

            return first.rssi > second.rssi
        }).first {
            selectDevice(bestMatch)
            statusText = "Found likely match: \(displayName(for: bestMatch))"
        } else {
            statusText = "No exact match found. Select the strongest nearby device and save it as \(searchText)."
        }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state

        diagnosis = diagnoseConnectionFailure(
            bluetoothState: central.state,
            lastRSSI: nil,
            wasAdvertising: false,
            isConnectable: nil,
            hasAdvertisedServices: nil,
            connectionError: nil,
            batteryLevel: nil,
            disappearedDuringConnection: false
        )
        

        switch central.state {
        case .poweredOn:
            statusText = "Bluetooth is on. Scanning for nearby devices..."
            startScanning()
        case .poweredOff:
            statusText = "Bluetooth is turned off."
        case .unauthorized:
            statusText = "Bluetooth permission denied."
        case .unsupported:
            statusText = "Bluetooth is unsupported on this device."
        case .resetting:
            statusText = "Bluetooth is resetting."
        case .unknown:
            statusText = "Bluetooth state is unknown."
        @unknown default:
            statusText = "Unknown Bluetooth state."
        }
    }

    func startDiagnosisRun() {
        let duration = UserDefaults.standard.integer(
            forKey: BluetoothDoctorSettings.scanDuration
        )

        let safeDuration = duration == 0 ? 8 : duration

        statusText = "Running Bluetooth diagnosis..."

        diagnosis = diagnoseConnectionFailure(
            bluetoothState: bluetoothState,
            lastRSSI: nil,
            wasAdvertising: false,
            isConnectable: nil,
            hasAdvertisedServices: nil,
            connectionError: nil,
            batteryLevel: nil,
            disappearedDuringConnection: false
        )

        startScanning()

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(safeDuration)) {
            self.stopScanning()

            let weakDevices = self.devices.filter { $0.rssi < -80 }
            let inspectableDevices = self.devices.filter { $0.isConnectable }

            if self.bluetoothState != .poweredOn {
                self.diagnosis = diagnoseConnectionFailure(
                    bluetoothState: self.bluetoothState,
                    lastRSSI: nil,
                    wasAdvertising: false,
                    isConnectable: nil,
                    hasAdvertisedServices: nil,
                    connectionError: nil,
                    batteryLevel: nil,
                    disappearedDuringConnection: false
                )
                return
            }

            if self.devices.isEmpty {
                self.statusText = "Diagnosis complete: no nearby BLE signals found."

                self.diagnosis = Diagnosis(
                    reason: .noDiagnosticData,
                    confidence: 0.7,
                    evidence: [
                        "Bluetooth is powered on",
                        "No nearby BLE advertisements were found during the scan"
                    ],
                    fix: "Wake the device, move it closer, put it in pairing mode if needed, then run diagnosis again."
                )
                return
            }

            if !weakDevices.isEmpty {
                self.statusText = "Diagnosis complete: \(weakDevices.count) weak BLE signal(s) found."

                self.diagnosis = Diagnosis(
                    reason: .weakSignalMayFail,
                    confidence: 0.75,
                    evidence: [
                        "Bluetooth is powered on",
                        "Found \(self.devices.count) nearby BLE signal(s)",
                        "\(weakDevices.count) signal(s) are weak",
                        "\(inspectableDevices.count) device(s) may expose BLE data"
                    ],
                    fix: "Select the device you care about from the sidebar. If its signal is weak, move it closer before inspecting BLE data."
                )
                return
            }

            self.statusText = "Diagnosis complete: Bluetooth looks ready."

            self.diagnosis = Diagnosis(
                reason: .readyToScan,
                confidence: 0.9,
                evidence: [
                    "Bluetooth is powered on",
                    "Found \(self.devices.count) nearby BLE signal(s)",
                    "\(inspectableDevices.count) device(s) may expose BLE data",
                    "No very weak signals were detected"
                ],
                fix: "Select the device you want to troubleshoot from the sidebar. BlueAssistMac will show device-specific next steps."
            )
        }
    }
    func startScanning() {
        guard let centralManager else {
            statusText = "Bluetooth manager has not been created yet."
            return
        }

        switch centralManager.state {
        case .poweredOn:
            devices.removeAll()
            statusText = "Scanning for nearby BLE devices..."

            centralManager.scanForPeripherals(
                withServices: nil,
                options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: true
                ]
            )

        case .poweredOff:
            statusText = "Bluetooth is powered off on this Mac."

        case .unauthorized:
            statusText = "BlueAssistMac does not have Bluetooth permission."

        case .unsupported:
            statusText = "Bluetooth is unsupported for this app/target."

        case .resetting:
            statusText = "Bluetooth is resetting. Try again in a few seconds."

        case .unknown:
            statusText = "Bluetooth state is unknown. Wait a moment and try again."

        @unknown default:
            statusText = "Unknown Bluetooth state."
        }
    }
    func stopScanning() {
        centralManager?.stopScan()
        statusText = "Scan stopped."
    }

    func selectDevice(_ device: BluetoothDevice) {
        selectedDevice = device
        batteryLevel = nil
        discoveredServices.removeAll()

        diagnosis = diagnoseConnectionFailure(
            bluetoothState: bluetoothState,
            lastRSSI: device.rssi,
            wasAdvertising: true,
            isConnectable: device.isConnectable,
            hasAdvertisedServices: device.hasAdvertisedServices,
            connectionError: nil,
            batteryLevel: batteryLevel,
            disappearedDuringConnection: false
        )
    }

    func displayName(
        peripheral: CBPeripheral,
        advertisementData: [String: Any]
    ) -> String {

        if let advertisedName = cleanedName(
            advertisementData[CBAdvertisementDataLocalNameKey] as? String
        ) {
            saveCachedName(advertisedName, for: peripheral.identifier)
            return advertisedName
        }

        if let peripheralName = cleanedName(peripheral.name) {
            saveCachedName(peripheralName, for: peripheral.identifier)
            return peripheralName
        }

        if let cached = cachedName(for: peripheral.identifier) {
            return cached
        }

        return "Unnamed BLE Device \(peripheral.identifier.uuidString.prefix(4))"
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let name = displayName(
            peripheral: peripheral,
            advertisementData: advertisementData
        )
        let device = BluetoothDevice(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            peripheral: peripheral,
            advertisementData: advertisementData
        )

        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else {
            devices.append(device)
        }

        devices.sort { $0.rssi > $1.rssi }

    }
   
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        connectedDeviceName = peripheral.name ?? selectedDevice?.name ?? "Unknown Device"
        statusText = "Connected to \(connectedDeviceName ?? "device")"

        peripheral.delegate = self

        peripheral.readRSSI()
        peripheral.discoverServices(nil)

        diagnosis = Diagnosis(
            reason: .connectedButLimitedData,
            confidence: 0.8,
            evidence: [
                "BlueAssistMac connected to the BLE device",
                "Service discovery has started"
            ],
            fix: "Waiting for services. Battery will appear only if the device exposes the standard BLE Battery Service."
        )

        if let selectedDevice,
           selectedDevice.id == peripheral.identifier {
            let updatedName = peripheral.name ?? selectedDevice.name

            let updatedDevice = BluetoothDevice(
                id: selectedDevice.id,
                name: updatedName,
                rssi: selectedDevice.rssi,
                peripheral: selectedDevice.peripheral,
                advertisementData: selectedDevice.advertisementData
            )

            self.selectedDevice = updatedDevice

            if let index = devices.firstIndex(where: { $0.id == updatedDevice.id }) {
                devices[index] = updatedDevice
            }
        }
    }
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        statusText = "Failed to connect to \(peripheral.name ?? selectedDevice?.name ?? "device")."

        diagnosis = diagnoseConnectionFailure(
            bluetoothState: bluetoothState,
            lastRSSI: selectedDevice?.rssi,
            wasAdvertising: selectedDevice != nil,
            isConnectable: selectedDevice?.isConnectable,
            hasAdvertisedServices: selectedDevice?.hasAdvertisedServices,
            connectionError: error,
            batteryLevel: batteryLevel,
            disappearedDuringConnection: false
        )
    }
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        statusText = "Disconnected from \(peripheral.name ?? "device")."
        connectedDeviceName = nil
        connectedPeripheral = nil
        batteryLevel = nil
        discoveredServices.removeAll()

        if let error {
            diagnosis = diagnoseConnectionFailure(
                bluetoothState: bluetoothState,
                lastRSSI: selectedDevice?.rssi,
                wasAdvertising: selectedDevice != nil,
                isConnectable: selectedDevice?.isConnectable,
                hasAdvertisedServices: selectedDevice?.hasAdvertisedServices,
                connectionError: error,
                batteryLevel: nil,
                disappearedDuringConnection: false
            )
        }
        
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didReadRSSI RSSI: NSNumber,
        error: Error?
    ) {
        guard error == nil else {
            statusText = "Could not read signal strength."
            return
        }

        statusText = "Connected. Signal strength: \(RSSI.intValue) dBm"
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        guard error == nil else {
            statusText = "Could not discover services."

            diagnosis = Diagnosis(
                reason: .noDiagnosticData,
                confidence: 0.65,
                evidence: ["Service discovery failed"],
                fix: "The device may not allow third-party apps to inspect its Bluetooth services."
            )

            return
        }

        let services = peripheral.services ?? []

        discoveredServices = services.map { service in
            service.uuid.uuidString
        }

        if services.isEmpty {
            diagnosis = Diagnosis(
                reason: .noDiagnosticData,
                confidence: 0.7,
                evidence: [
                    "Connected successfully",
                    "No BLE services were discovered"
                ],
                fix: "The device connected, but it does not expose readable services to BlueAssistMac."
            )
        } else if services.contains(where: { $0.uuid == batteryServiceUUID }) {
            diagnosis = Diagnosis(
                reason: .connectedButLimitedData,
                confidence: 0.85,
                evidence: [
                    "Connected successfully",
                    "Battery Service was found",
                    "Discovered \(services.count) BLE service(s)"
                ],
                fix: "BlueAssistMac found the Battery Service and is trying to read the battery level."
            )
        } else {
            diagnosis = Diagnosis(
                reason: .connectedButLimitedData,
                confidence: 0.75,
                evidence: [
                    "Connected successfully",
                    "Discovered \(services.count) BLE service(s)",
                    "Battery Service was not found"
                ],
                fix: "The device is connected, but it does not expose the standard BLE Battery Service."
            )
        }

        for service in services {
            if service.uuid == batteryServiceUUID {
                peripheral.discoverCharacteristics([batteryLevelUUID], for: service)
            } else {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == batteryLevelUUID {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    func disconnect() {
        guard let connectedPeripheral else {
            statusText = "No connected device to disconnect."
            return
        }

        centralManager?.cancelPeripheralConnection(connectedPeripheral)
    }
    func inspectSelectedBLEDevice() {
        guard let selectedDevice else {
            statusText = "No device selected."
            return
        }

        guard selectedDevice.isConnectable else {
            statusText = "\(selectedDevice.name) is not connectable."

            diagnosis = Diagnosis(
                reason: .notConnectable,
                confidence: 0.75,
                evidence: ["Device is advertising but marked as not connectable"],
                fix: "Put the device in pairing mode, wake it up, or choose a connectable BLE device."
            )

            return
        }

        stopScanning()

        batteryLevel = nil
        discoveredServices.removeAll()
        connectedDeviceName = nil

        connectedPeripheral = selectedDevice.peripheral
        connectedPeripheral?.delegate = self

        statusText = "Inspecting BLE data for \(selectedDevice.name)..."

        centralManager?.connect(
            selectedDevice.peripheral,
            options: nil
            
        )
        scheduleConnectionTimeout(for: selectedDevice)
    }
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil else {
            statusText = "Could not read value for \(characteristic.uuid.uuidString)."
            return
        }

        if characteristic.uuid == batteryLevelUUID,
           let data = characteristic.value,
           let firstByte = data.first {

            batteryLevel = Int(firstByte)
            statusText = "Battery level: \(batteryLevel ?? 0)%"

            diagnosis = diagnoseConnectionFailure(
                bluetoothState: bluetoothState,
                lastRSSI: selectedDevice?.rssi,
                wasAdvertising: selectedDevice != nil,
                isConnectable: selectedDevice?.isConnectable,
                hasAdvertisedServices: selectedDevice?.hasAdvertisedServices,
                connectionError: nil,
                batteryLevel: batteryLevel,
                disappearedDuringConnection: false
            )
        }
    }
}

struct BluetoothDevice: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
    let advertisementData: [String: Any]

    var isConnectable: Bool {
        advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? false
    }

    var hasAdvertisedServices: Bool {
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        return !(services?.isEmpty ?? true)
    }

    var signalLabel: String {
        switch rssi {
        case -50...0:
            return "Excellent"
        case -65 ..< -50:
            return "Good"
        case -80 ..< -65:
            return "Weak"
        default:
            return "Very weak"
        }
    }
    var manufacturerText: String? {
        guard let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
            return nil
        }

        guard data.count >= 2 else {
            return nil
        }

        let companyID = UInt16(data[0]) | (UInt16(data[1]) << 8)

        switch companyID {
        case 0x004C:
            return "Apple nearby device"
        case 0x0006:
            return "Microsoft nearby device"
        case 0x0075:
            return "Samsung nearby device"
        case 0x000F:
            return "Broadcom nearby device"
        case 0x00E0:
            return "Google nearby device"
        case 0x0118:
            return "JBL nearby device"
        case 0x0131:
            return "Tile tracker"
        default:
            return "Manufacturer ID: 0x\(String(companyID, radix: 16).uppercased())"
        }
    }

    var signalColor: Color {
        switch rssi {
        case -60...0:
            return .green
        case -80 ..< -60:
            return .yellow
        default:
            return .red
        }
    }

    var connectableText: String {
        isConnectable ? "Connectable" : "Not connectable"
    }

    var connectableColor: Color {
        isConnectable ? .green : .red
    }

    var advertisedServicesText: String {
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        guard let services, !services.isEmpty else {
            return "No advertised services"
        }

        return services.map { $0.uuidString }.joined(separator: ", ")
    }
}



struct BlueAssistSidebar: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var macBluetoothManager: MacSystemBluetoothManager

    let macDevices: [MacSystemBluetoothDevice]
    let bleDevices: [BluetoothDevice]

    @Binding var selection: SidebarSelection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sidebarHeader

                SidebarGlassSection(
                    title: "Known Mac Devices",
                    subtitle: "paired through macOS"
                ) {
                    if macDevices.isEmpty {
                        SidebarEmptyRow(
                            title: "No paired devices",
                            subtitle: macBluetoothManager.statusText
                        )
                    } else {
                        ForEach(macDevices) { device in
                            SidebarMacDeviceRow(
                                device: device,
                                isSelected: selection == .mac(device.id)
                            ) {
                                selection = .mac(device.id)
                            }
                        }
                    }
                }

                SidebarGlassSection(
                    title: "Nearby BLE Signals",
                    subtitle: "visible low-energy broadcasts"
                ) {
                    if bleDevices.isEmpty {
                        SidebarEmptyRow(
                            title: "No BLE signals found",
                            subtitle: bluetoothManager.statusText
                        )
                    } else {
                        ForEach(bleDevices) { device in
                            SidebarBLEDeviceRow(
                                device: device,
                                bluetoothManager: bluetoothManager,
                                isSelected: selection == .ble(device.id)
                            ) {
                                selection = .ble(device.id)
                            }
                        }
                    }
                }

                sidebarFooter
            }
            .padding(14)
        }
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                LinearGradient(
                    colors: [
                        .blue.opacity(0.16),
                        .clear,
                        .cyan.opacity(0.08)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.45)
            }
            .ignoresSafeArea()
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("BlueAssist")
                        .font(.headline)

                    Text("Bluetooth diagnosis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Label("\(bleDevices.count)", systemImage: "antenna.radiowaves.left.and.right")
                Label("\(macDevices.count)", systemImage: "link")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .blueGlassPanel(cornerRadius: 22, padding: 14)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(statusLabel, systemImage: statusIcon)
                .font(.subheadline.bold())
                .foregroundStyle(statusColor)

            Text(bluetoothManager.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .blueGlassPanel(cornerRadius: 20, padding: 14)
    }

    private var statusLabel: String {
        switch bluetoothManager.bluetoothState {
        case .poweredOn:
            return "Bluetooth ready"
        case .poweredOff:
            return "Bluetooth off"
        case .unauthorized:
            return "Permission needed"
        case .unsupported:
            return "Unsupported"
        case .resetting:
            return "Resetting"
        case .unknown:
            return "Checking"
        @unknown default:
            return "Unknown"
        }
    }

    private var statusIcon: String {
        switch bluetoothManager.bluetoothState {
        case .poweredOn:
            return "checkmark.circle.fill"
        case .poweredOff:
            return "power.circle.fill"
        case .unauthorized:
            return "lock.circle.fill"
        case .unsupported:
            return "xmark.octagon.fill"
        case .resetting:
            return "arrow.clockwise.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch bluetoothManager.bluetoothState {
        case .poweredOn:
            return .green
        case .poweredOff, .unauthorized, .unsupported:
            return .red
        case .resetting, .unknown:
            return .yellow
        @unknown default:
            return .secondary
        }
    }
}


struct SidebarGlassSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                content
            }
        }
    }
}
struct SidebarSelectableGlassRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button {
            action()
        } label: {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isSelected
                    ? Color.blue.opacity(0.38)
                    : Color.white.opacity(0.045)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected
                    ? Color.blue.opacity(0.55)
                    : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        }
        .shadow(
            color: isSelected ? .blue.opacity(0.28) : .clear,
            radius: isSelected ? 12 : 0,
            x: 0,
            y: 5
        )
    }
}

struct SidebarMacDeviceRow: View {
    let device: MacSystemBluetoothDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SidebarSelectableGlassRow(
            isSelected: isSelected,
            action: action
        ) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(device.isConnected ? .green.opacity(0.18) : .red.opacity(0.14))
                        .frame(width: 34, height: 34)

                    Image(systemName: iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(device.isConnected ? .green : .secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(device.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        StatusPill(
                            text: device.isConnected ? "Connected" : "Not connected",
                            color: device.isConnected ? .green : .red
                        )

                        StatusPill(
                            text: device.isPaired ? "Paired" : "Not paired",
                            color: device.isPaired ? .green : .red
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var iconName: String {
        let lowered = device.name.lowercased()

        if lowered.contains("airpods") || lowered.contains("beats") {
            return "airpodspro"
        }

        if lowered.contains("keyboard") {
            return "keyboard"
        }

        if lowered.contains("mouse") {
            return "computermouse"
        }

        if lowered.contains("trackpad") {
            return "rectangle.and.hand.point.up.left"
        }

        if lowered.contains("ipad") || lowered.contains("iphone") {
            return "iphone"
        }

        return "link"
    }
}
struct SidebarBLEDeviceRow: View {
    let device: BluetoothDevice
    @ObservedObject var bluetoothManager: BluetoothManager
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SidebarSelectableGlassRow(
            isSelected: isSelected,
            action: action
        ) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(device.signalColor.opacity(0.16))
                        .frame(width: 34, height: 34)

                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(device.signalColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(bluetoothManager.displayName(for: device))
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        StatusPill(
                            text: device.signalLabel,
                            color: device.signalColor
                        )

                        StatusPill(
                            text: "\(device.rssi) dBm",
                            color: device.signalColor
                        )
                    }

                    HStack(spacing: 6) {
                        StatusPill(
                            text: device.isConnectable ? "BLE inspectable" : "Signal only",
                            color: device.isConnectable ? .green : .red
                        )
                    }

                    if let manufacturer = device.manufacturerText {
                        Text(manufacturer)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}
struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                color.opacity(0.12),
                in: Capsule()
            )
    }
}

struct SidebarEmptyRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.bold())

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }
}
