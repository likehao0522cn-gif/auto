import SwiftUI
import UIKit

struct TapTempoPad: UIViewRepresentable {
    let tapCount: Int
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> TapPadUIView {
        let view = TapPadUIView()
        view.isAccessibilityElement = true
        view.accessibilityLabel = "测速拍点区域"
        view.accessibilityHint = "单次触摸此区域即可记录一拍"
        view.accessibilityIdentifier = "TapTempoPad"
        view.accessibilityTraits = [.button, .allowsDirectInteraction]
        view.onTap = context.coordinator.onTap
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: TapPadUIView, context: Context) {
        context.coordinator.onTap = onTap
        uiView.accessibilityValue = "已记录 \(tapCount) 拍"
    }

    final class Coordinator {
        var onTap: () -> Void
        weak var view: TapPadUIView?

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }
    }
}

final class TapPadUIView: UIView {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(recognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }

    override func accessibilityActivate() -> Bool {
        onTap?()
        return true
    }
}
