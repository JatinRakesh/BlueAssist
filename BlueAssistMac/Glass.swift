
//  Glass.swift
//  BlueAssistMac
//
//  Created by Jatin Rakesh on 25/6/26.
//

import SwiftUI
import CoreBluetooth

struct BlueAssistBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            RadialGradient(
                colors: [
                    .blue.opacity(0.25),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 80,
                endRadius: 520
            )

            RadialGradient(
                colors: [
                    .cyan.opacity(0.12),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 80,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass helpers

extension View {
    @ViewBuilder
    func blueGlassPanel(
        cornerRadius: CGFloat = 24,
        padding: CGFloat = 16
    ) -> some View {
        if #available(macOS 26.0, *) {
            self
                .padding(padding)
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            self
                .padding(padding)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                    .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func blueGlassControl(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .glassEffect(
                        .regular
                            .tint(.blue.opacity(0.85))
                            .interactive(),
                        in: .capsule
                    )
            } else {
                self
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .glassEffect(
                        .regular
                            .interactive(),
                        in: .capsule
                    )
            }
        } else {
            self
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    prominent ? Color.blue : Color.secondary.opacity(0.18),
                    in: Capsule()
                )
        }
    }
}

// MARK: - Reusable row

struct InfoLine: View {
    let title: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}

// MARK: - Start dashboard

struct StartDashboardView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var macBluetoothManager: MacSystemBluetoothManager
    @Binding var selection: SidebarSelection?

    private var weakDevices: [BluetoothDevice] {
        bluetoothManager.devices.filter { $0.rssi < -80 }
    }

    private var inspectableDevices: [BluetoothDevice] {
        bluetoothManager.devices.filter { $0.isConnectable }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard

                HStack(spacing: 14) {
                    MiniStatusCard(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Bluetooth",
                        value: bluetoothManager.statusText
                    )

                    MiniStatusCard(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Nearby signals",
                        value: "\(bluetoothManager.devices.count) BLE signal(s)"
                    )

                    MiniStatusCard(
                        icon: "waveform.path.ecg",
                        title: "Inspectable",
                        value: "\(inspectableDevices.count) BLE device(s)"
                    )

                    MiniStatusCard(
                        icon: "link",
                        title: "Known devices",
                        value: "\(macBluetoothManager.pairedDevices.count) paired"
                    )
                }

                quickHelpCard
            }
            .padding(28)
        }
        .background(BlueAssistBackground())
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Why won’t my device connect?")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Start diagnosis checks Bluetooth status, permissions, nearby BLE signals, paired devices, weak range, and public BLE data. no random weakest-device guessing.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "stethoscope")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, isActive: true)
            }

            HStack(spacing: 12) {
                Button {
                    bluetoothManager.startDiagnosisRun()
                    macBluetoothManager.loadPairedDevices()
                } label: {
                    Label("Start diagnosis", systemImage: "waveform.path.ecg")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .blueGlassControl(prominent: true)

                Button {
                    openBluetoothSettings()
                } label: {
                    Label("Open bluetooth settings", systemImage: "gearshape")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .blueGlassControl()
            }

            Divider()
                .opacity(0.35)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)

                Text("BlueAssistMac can inspect BLE data, but normal AirPods, audio, keyboard, mouse, Find My, and other system-managed connections are controlled by macOS Bluetooth Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .blueGlassPanel(cornerRadius: 30, padding: 26)
    }

    private var quickHelpCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("what BlueAssistMac checks")
                .font(.headline)

            QuickHelpRow(
                icon: "ruler",
                title: "Range",
                detail: "Weak RSSI usually means the device is too far away or blocked."
            )

            QuickHelpRow(
                icon: "battery.50percent",
                title: "Battery",
                detail: "Some BLE devices expose battery level after inspection."
            )

            QuickHelpRow(
                icon: "lock.shield",
                title: "Permissions",
                detail: "MacOS Bluetooth permission can block inspection."
            )

            QuickHelpRow(
                icon: "link.badge.plus",
                title: "Pairing state",
                detail: "Paired devices and nearby BLE signals are handled differently."
            )

            QuickHelpRow(
                icon: "gearshape.2",
                title: "System-managed devices",
                detail: "AirPods, Find My, audio, keyboards, and mice may need macOS Bluetooth Settings."
            )
        }
        .blueGlassPanel(cornerRadius: 22)
    }

    private func openBluetoothSettings() {
        let settingsURLs = [
            "x-apple.systempreferences:com.apple.BluetoothSettings",
            "x-apple.systempreferences:com.apple.preference.bluetooth"
        ]

        for rawURL in settingsURLs {
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
}

// MARK: - Mini status card

struct MiniStatusCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(title)
                .font(.headline)

            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueGlassPanel(cornerRadius: 18, padding: 14)
    }
}

// MARK: - Quick help row

struct QuickHelpRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

