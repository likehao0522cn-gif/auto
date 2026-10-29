import SwiftUI

struct InstrumentPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: preset.displayName))
            .accessibilityValue(Text(verbatim: preset.id == appModel.selectedPresetID ? "已选择" : "未选择"))
        }
        .navigationTitle("选择乐器")
    }
}
