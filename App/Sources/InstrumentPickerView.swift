import SwiftUI

struct InstrumentPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(appModel.presets) { preset in
                Button {
                    appModel.selectPreset(preset)
                    dismiss()
                } label: {
                    HStack {
                        Text(verbatim: preset.displayName)
                        Spacer()
                        if preset.id == appModel.selectedPresetID {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: preset.displayName))
                .accessibilityAddTraits(preset.id == appModel.selectedPresetID ? [.isSelected] : [])
            }
            .navigationTitle("选择乐器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: "取消")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "取消选择乐器"))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
