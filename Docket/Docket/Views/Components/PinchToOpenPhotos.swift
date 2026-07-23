import SwiftUI

extension View {
    /// Gives a photo-bearing card a small elastic preview before opening its
    /// full-screen gallery at the end of a deliberate pinch-out gesture.
    func pinchToOpenPhotos(
        isEnabled: Bool,
        onOpen: @escaping () -> Void
    ) -> some View {
        modifier(PinchToOpenPhotosModifier(isEnabled: isEnabled, onOpen: onOpen))
    }
}

private struct PinchToOpenPhotosModifier: ViewModifier {
    let isEnabled: Bool
    let onOpen: () -> Void

    @State private var previewScale: CGFloat = 1
    @State private var isArmed = false
    @State private var didOpen = false
    @State private var openFeedbackTrigger = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(previewScale)
            .simultaneousGesture(pinchGesture, isEnabled: isEnabled)
            .sensoryFeedback(.selection, trigger: isArmed) { wasArmed, isArmed in
                !wasArmed && isArmed
            }
            .sensoryFeedback(
                .impact(weight: .light, intensity: 0.7),
                trigger: openFeedbackTrigger
            )
            .accessibilityAction(named: "View Photos") {
                guard isEnabled else { return }
                onOpen()
            }
            .onChange(of: isEnabled) { _, enabled in
                guard !enabled else { return }
                resetPreview()
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                guard isEnabled, !didOpen else { return }

                let magnification = max(value.magnification, 1)
                let elasticGrowth = min(
                    (magnification - 1) * DocketTheme.PhotoViewer.cardPreviewResistance,
                    DocketTheme.PhotoViewer.cardPreviewMaximumGrowth
                )
                previewScale = 1 + elasticGrowth
                isArmed = magnification >= DocketTheme.PhotoViewer.openThreshold
            }
            .onEnded { _ in
                guard isEnabled, !didOpen else {
                    resetPreview()
                    return
                }

                if isArmed {
                    didOpen = true
                    openFeedbackTrigger += 1
                    onOpen()
                }

                resetPreview()
                Task { @MainActor in
                    await Task.yield()
                    didOpen = false
                }
            }
    }

    private func resetPreview() {
        withAnimation(DocketTheme.PhotoViewer.cardPreviewResetAnimation) {
            previewScale = 1
            isArmed = false
        }
    }
}
