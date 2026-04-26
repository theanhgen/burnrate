import SwiftUI

/// A button style that provides visual feedback for both hover and pressed states.
/// Used for cards and rows that should feel interactive.
struct InteractiveButtonStyle: ButtonStyle {
    let baseOpacity: Double
    let hoverOpacity: Double
    let pressedOpacity: Double
    let cornerRadius: CGFloat
    let color: Color?

    init(
        baseOpacity: Double = 0.05,
        hoverOpacity: Double = 0.10,
        pressedOpacity: Double = 0.15,
        cornerRadius: CGFloat = 8,
        color: Color? = nil
    ) {
        self.baseOpacity = baseOpacity
        self.hoverOpacity = hoverOpacity
        self.pressedOpacity = pressedOpacity
        self.cornerRadius = cornerRadius
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        InteractiveButtonContent(
            configuration: configuration,
            baseOpacity: baseOpacity,
            hoverOpacity: hoverOpacity,
            pressedOpacity: pressedOpacity,
            cornerRadius: cornerRadius,
            color: color
        )
    }

    private struct InteractiveButtonContent: View {
        let configuration: ButtonStyle.Configuration
        let baseOpacity: Double
        let hoverOpacity: Double
        let pressedOpacity: Double
        let cornerRadius: CGFloat
        let color: Color?

        @State private var isHovered = false

        var body: some View {
            let activeColor = color ?? .primary
            let backgroundOpacity = configuration.isPressed
                ? pressedOpacity
                : (isHovered ? hoverOpacity : baseOpacity)

            configuration.label
                .background(activeColor.opacity(backgroundOpacity))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(activeColor.opacity(isHovered ? 0.2 : 0.1), lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: isHovered)
                .onHover { isHovered = $0 }
        }
    }
}

/// A simpler button style for small icon buttons in the header.
struct HeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              let int = UInt64(hex, radix: 16) else {
            return nil
        }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
