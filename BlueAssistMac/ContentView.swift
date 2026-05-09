

import SwiftUI
import Foundation
import CoreBluetooth
import Combine

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

    @State private var showingFindMyDevice = false
    @State private var searchText: String = ""
    @State private var selection: SidebarSelection?

    var selectedMacDevice: MacSystemBluetoothDevice? {
        guard case let .mac(id) = selection else { return nil }
        return macBluetoothManager.pairedDevices.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Paired Mac Bluetooth Devices") {
                    if filteredMacDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No paired Mac devices loaded")
                                .font(.headline)

                            Text(macBluetoothManager.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(filteredMacDevices) { device in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.headline)

                                HStack {
                                    Text(device.isConnected ? "Connected" : "Not Connected")
                                        .foregroundStyle(device.isConnected ? .green : .red)

                                    Text(device.isPaired ? "Paired" : "Not Paired")
                                        .foregroundStyle(device.isPaired ? .green : .red)
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                            .tag(SidebarSelection.mac(device.id))
                        }
                    }
                }

                Section("Nearby Bluetooth Devices") {
                    if filteredBLEDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No nearby BLE devices found")
                                .font(.headline)

                            Text(bluetoothManager.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(filteredBLEDevices) { device in
                            DeviceRow(
                                device: device,
                                bluetoothManager: bluetoothManager
                            )
                            .tag(SidebarSelection.ble(device.id))
                        }
                    }
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
            .searchable(text: $searchText, prompt: "Search for a paired device")
            .navigationTitle("BlueAssist")
            .toolbar {
                Button("Find My Device") {
                    showingFindMyDevice = true
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
            .sheet(isPresented: $showingFindMyDevice) {
                FindMyDeviceView(
                    bluetoothManager: bluetoothManager,
                    macBluetoothManager: macBluetoothManager,
                    selection: $selection
                )
            }
        } detail: {
            switch selection {
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
                VStack(spacing: 12) {
                    Text(bluetoothManager.statusText)
                        .font(.headline)

                    Text("Select a Bluetooth device to view details.")
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

struct DeviceRow: View {
    let device: BluetoothDevice
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bluetoothManager.displayName(for: device))
                .font(.headline)

            HStack(spacing: 8) {
                Text(device.signalLabel)
                    .foregroundStyle(device.signalColor)

                Text("\(device.rssi) dBm")
                    .foregroundStyle(device.signalColor)

                Text(device.connectableText)
                    .foregroundStyle(device.connectableColor)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct DeviceDetailView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var macBluetoothManager: MacSystemBluetoothManager
    @State private var nicknameText: String = ""

    var body: some View {
        if let device = bluetoothManager.selectedDevice {
            List {
                Section("Nickname") {
                    TextField("Custom name for this device", text: $nicknameText)

                    Button("Save Nickname") {
                        bluetoothManager.saveNickname(nicknameText, for: device)
                    }

                    if let savedNickname = bluetoothManager.nickname(for: device) {
                        LabeledContent("Saved Name", value: savedNickname)
                    }
                }

                Section("Status") {
                    LabeledContent("BlueAssist Status", value: bluetoothManager.statusText)

                    if let connectedName = bluetoothManager.connectedDeviceName {
                        LabeledContent("Connected Device", value: connectedName)
                    } else {
                        LabeledContent("Connected Device", value: "None")
                    }
                }

                Section("Device") {
                    LabeledContent("Name", value: device.name)
                    LabeledContent("Identifier", value: device.id.uuidString)
                    LabeledContent("Connectable", value: device.connectableText)
                }

                Section("Signal") {
                    LabeledContent("RSSI", value: "\(device.rssi) dBm")
                    LabeledContent("Signal Quality", value: device.signalLabel)
                }

                Section("Battery") {
                    if let batteryLevel = bluetoothManager.batteryLevel {
                        LabeledContent("Battery Level", value: "\(batteryLevel)%")
                    } else {
                        LabeledContent("Battery Level", value: "Not available")
                    }
                }

                Section("Advertised Services") {
                    Text(device.advertisedServicesText)
                        .font(.caption)
                        .textSelection(.enabled)
                }

                Section("Discovered Services") {
                    if bluetoothManager.discoveredServices.isEmpty {
                        Text("Connect to the device to discover services.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(bluetoothManager.discoveredServices, id: \.self) { service in
                            Text(service)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }

                Section("Diagnosis") {
                    if let diagnosis = bluetoothManager.diagnosis {
                        LabeledContent("Reason", value: diagnosis.reason.rawValue)
                        LabeledContent("Confidence", value: "\(Int(diagnosis.confidence * 100))%")

                        Text(diagnosis.fix)
                            .foregroundStyle(.secondary)

                        if !diagnosis.evidence.isEmpty {
                            ForEach(diagnosis.evidence, id: \.self) { item in
                                Text("• \(item)")
                                    .font(.caption)
                            }
                        }
                    } else {
                        Text("Select a device to diagnose.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Actions") {
                    if device.isConnectable {
                        Button("Connect and Inspect") {
                            bluetoothManager.connectToSelectedDevice()
                        }

                        Button("Disconnect") {
                            bluetoothManager.disconnect()
                        }
                    } else {
                        Text("This device is not connectable through BlueAssist.")
                            .foregroundStyle(.secondary)

                        Text("It may be a system-managed Bluetooth device, Classic Bluetooth device, or a BLE broadcaster.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Scan Again") {
                        bluetoothManager.startScanning()
                        macBluetoothManager.loadPairedDevices()
                    }
                }
            }
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
struct Diagnosis{
    let reason: FailureReason
    let confidence: Double
    let evidence: [String]
    let fix: String
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
            fix: "Wait while BlueAssist checks Bluetooth status."
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
            evidence: ["BlueAssist does not have Bluetooth permission"],
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
        evidence: ["BlueAssist does not yet have enough connection data"],
        fix: "Try Connect and Inspect, move closer, or check whether the device is already connected somewhere else."
    )
}


final class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
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
    func nicknameKey(for id: UUID) -> String {
        "nickname_\(id.uuidString)"
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
            statusText = "BlueAssist does not have Bluetooth permission."

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
        if let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
           !advertisedName.isEmpty {
            return advertisedName
        }

        if let peripheralName = peripheral.name,
           !peripheralName.isEmpty {
            return peripheralName
        }

        return "Unknown Device"
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
                "BlueAssist connected to the BLE device",
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
                fix: "The device connected, but it does not expose readable services to BlueAssist."
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
                fix: "BlueAssist found the Battery Service and is trying to read the battery level."
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
    func connectToSelectedDevice() {
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

        statusText = "Connecting to \(selectedDevice.name)..."

        centralManager?.connect(
            selectedDevice.peripheral,
            options: nil
        )
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
struct FindDeviceResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let score: Int
    let selection: SidebarSelection
}
struct FindMyDeviceView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var macBluetoothManager: MacSystemBluetoothManager
    @Binding var selection: SidebarSelection?

    @Environment(\.dismiss) private var dismiss

    @State private var searchName: String = ""
    @State private var results: [FindDeviceResult] = []
    @State private var hasSearched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find My Device")
                .font(.largeTitle)
                .bold()

            Text("Enter the device name. BlueAssist will show the best 10–20 candidates using paired devices, nearby BLE devices, signal strength, connectability, and saved nicknames.")
                .foregroundStyle(.secondary)

            TextField("Example: ACHYUT, AirPods, Samsung, JBL, TWS", text: $searchName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    runSearch()
                }

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Find Best Matches") {
                    runSearch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            if hasSearched {
                if results.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No matches found")
                            .font(.headline)

                        Text("Try scanning again, use a shorter name, or select an Unknown Device and save a nickname.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Best Matches")
                        .font(.headline)

                    List(results) { result in
                        Button {
                            selection = result.selection
                            applySelection(result.selection)

                            dismiss()

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                bluetoothManager.startScanning()
                                macBluetoothManager.loadPairedDevices()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.headline)

                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("\(result.score)%")
                                    .font(.caption)
                                    .foregroundStyle(scoreColor(result.score))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 340)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tip")
                        .font(.headline)

                    Text("Unknown devices are included in the results based on signal strength and connectability. Move the device closer and scan again to help identify it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 620, height: 560)
    }

    private func runSearch() {
        let query = searchName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else { return }

        hasSearched = true

        macBluetoothManager.loadPairedDevices()
        bluetoothManager.startScanning()

        let macResults = macBluetoothManager.pairedDevices.map { device in
            FindDeviceResult(
                title: device.name,
                subtitle: "Paired Mac device • \(device.isConnected ? "Connected" : "Not connected")",
                score: scoreMacDevice(device, query: query),
                selection: .mac(device.id)
            )
        }

        let bleResults = bluetoothManager.devices.map { device in
            let shownName = bluetoothManager.displayName(for: device)

            return FindDeviceResult(
                title: shownName,
                subtitle: "Nearby BLE • \(device.rssi) dBm • \(device.connectableText)",
                score: scoreBLEDevice(device, shownName: shownName, query: query),
                selection: .ble(device.id)
            )
        }

        /*
         Important:
         Do NOT filter out low-score BLE unknown devices.
         Unknown devices may be the user's target device.
        */
        results = (macResults + bleResults)
            .sorted { first, second in
                if first.score == second.score {
                    return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
                }

                return first.score > second.score
            }
            .prefix(20)
            .map { $0 }
    }

    private func applySelection(_ newSelection: SidebarSelection) {
        switch newSelection {
        case .ble(let id):
            if let device = bluetoothManager.devices.first(where: { $0.id == id }) {
                bluetoothManager.selectDevice(device)
            }

        case .mac:
            bluetoothManager.selectedDevice = nil
        }
    }

    private func scoreMacDevice(_ device: MacSystemBluetoothDevice, query: String) -> Int {
        var score = nameScore(name: device.name, query: query)

        if device.isConnected {
            score += 15
        }

        if device.isPaired {
            score += 10
        }

        /*
         Paired devices are useful, but do not let them completely bury
         nearby BLE unknown devices.
        */
        return min(score, 90)
    }

    private func scoreBLEDevice(_ device: BluetoothDevice, shownName: String, query: String) -> Int {
        var score = nameScore(name: shownName, query: query)

        if device.isConnectable {
            score += 20
        }

        if device.hasAdvertisedServices {
            score += 10
        }

        switch device.rssi {
        case -55...0:
            score += 35
        case -70 ..< -55:
            score += 25
        case -85 ..< -70:
            score += 15
        case -95 ..< -85:
            score += 8
        default:
            score += 3
        }

        /*
         Unknown devices should still show up.
         Strong/connectable unknown devices might be the user’s device.
        */
        if shownName.lowercased() == "unknown device" {
            score += 8
        }

        return min(score, 100)
    }

    private func nameScore(name: String, query: String) -> Int {
        let name = name.lowercased()
        let query = query.lowercased()

        if name == query {
            return 60
        }

        if name.contains(query) {
            return 50
        }

        if query.contains(name), name != "unknown device" {
            return 40
        }

        let queryWords = query
            .split(separator: " ")
            .map { String($0) }

        let matchedWords = queryWords.filter { word in
            name.contains(word)
        }

        if !matchedWords.isEmpty {
            return 20 + min(matchedWords.count * 8, 24)
        }

        return 0
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 75...100:
            return .green
        case 40 ..< 75:
            return .yellow
        default:
            return .red
        }
    }
}


