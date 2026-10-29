import SwiftUI

struct StringPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(appModel.selectedPreset.strings) { string in
            Button {
                appModel.selectString(string)
                dismiss()
            } label: {
                HStack {
                    Text(verbatim: appModel.displayName(for: string))
                    Spacer()
                    if string.id == appModel.selectedStringID {
                        Image(systemName: "checkmark")
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: appModel.displayName(for: string)))
            .accessibilityValue(Text(verbatim: string.id == appModel.selectedStringID ? "已选择" : "未选择"))
        }
        .navigationTitle("选择弦位")
    }
}
