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
                    Text(preset.displayName)
                    Spacer()
                    if preset.id == appModel.selectedPresetID {
                        Image(systemName: "checkmark")
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityLabel(preset.displayName)
            .accessibilityValue(preset.id == appModel.selectedPresetID ? "已选择" : "未选择")
            .accessibilityHint("双击选择这个乐器")
        }
        .navigationTitle("选择乐器")
    }
}
