//
//  diagnosis view.swift
//  BlueAssistMac
//
//  Created by Jatin Rakesh on 19/5/26.
//

import SwiftUI

enum DiagnosticSeverity {
    case healthy
    case warning
    case issue
    case unknown

    var label: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .warning:
            return "Warning"
        case .issue:
            return "Needs attention"
        case .unknown:
            return "Needs more data"
        }
    }

    var iconName: String {
        switch self {
        case .healthy:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .issue:
            return "xmark.octagon.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .healthy:
            return .green
        case .warning:
            return .yellow
        case .issue:
            return .red
        case .unknown:
            return .secondary
        }
    }
}

struct DiagnosisSummaryView: View {
    let title: String
    let reason: String
    let confidence: Double
    let severity: DiagnosticSeverity
    let fix: String
    let evidence: [String]
    let showsEvidence: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(severity.tint.opacity(0.16))
                        .frame(width: 64, height: 64)

                    Image(systemName: severity.iconName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(severity.tint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(reason)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(severity.label)
                        .font(.subheadline.bold())
                        .foregroundStyle(severity.tint)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(Int(confidence * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ProgressView(value: confidence)
                        .frame(width: 120)
                        .tint(severity.tint)
                        .accessibilityLabel("Diagnosis confidence")
                        .accessibilityValue("\(Int(confidence * 100)) percent")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What to do next")
                    .font(.headline)

                Text(fix)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsEvidence, !evidence.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("What BlueAssistMac observed")
                        .font(.headline)

                    ForEach(evidence, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)

                            Text(item)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .blueGlassPanel(cornerRadius: 26, padding: 22)
    }
}
