import SwiftUI
import UIKit

/// A large, VoiceOver-friendly numeric adjuster with explicit minus and plus buttons.
struct AdjustableValueRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueLabel: (Double) -> String

    private let epsilon = 0.000_001

    private var canDecrease: Bool {
        value > range.lowerBound + epsilon
    }

    private var canIncrease: Bool {
        value < range.upperBound - epsilon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: title)
                .font(.headline)
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                adjustButton(
                    symbol: "minus",
                    text: "减",
                    label: "减小\(title)",
                    enabled: canDecrease,
                    delta: -step
                )

                Text(verbatim: valueLabel(value))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .padding(.horizontal, 6)
                    .background(
                        Color(uiColor: .tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: title))
                    .accessibilityValue(Text(verbatim: valueLabel(value)))

                adjustButton(
                    symbol: "plus",
                    text: "加",
                    label: "增大\(title)",
                    enabled: canIncrease,
                    delta: step
                )
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            let clamped = min(range.upperBound, max(range.lowerBound, value))
            if abs(clamped - value) > epsilon {
                value = clamped
            }
        }
    }

    private func adjustButton(
        symbol: String,
        text: String,
        label: String,
        enabled: Bool,
        delta: Double
    ) -> some View {
        Button {
            adjust(by: delta)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                Text(verbatim: text)
                    .font(.caption.weight(.semibold))
            }
            .frame(minWidth: 64, minHeight: 52)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(!enabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityHint(Text(verbatim: "当前\(valueLabel(value))"))
    }

    private func adjust(by delta: Double) {
        let lower = range.lowerBound
        let upper = range.upperBound
        let next = min(upper, max(lower, value + delta))
        let normalized = (next * 1_000_000).rounded() / 1_000_000
        let adjusted = min(upper, max(lower, normalized))
        guard abs(adjusted - value) > epsilon else { return }
        value = adjusted

        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .announcement,
                argument: "\(title)，\(valueLabel(adjusted))"
            )
        }
    }
}