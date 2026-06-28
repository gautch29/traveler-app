import SwiftUI

public struct LiquidGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var fillOpacity: Double
    public var borderOpacity: Double
    
    public init(cornerRadius: CGFloat = 12, fillOpacity: Double = 0.03, borderOpacity: Double = 0.45) {
        self.cornerRadius = cornerRadius
        self.fillOpacity = fillOpacity
        self.borderOpacity = borderOpacity
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(fillOpacity))
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(fillOpacity * 2.0),
                                    Color.white.opacity(0.005)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.15),
                                Color.clear,
                                Color.white.opacity(borderOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

public struct GlassTextFieldModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .foregroundColor(.primary)
    }
}

extension View {
    public func liquidGlassStyle(cornerRadius: CGFloat = 12, fillOpacity: Double = 0.03, borderOpacity: Double = 0.45) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, fillOpacity: fillOpacity, borderOpacity: borderOpacity))
    }
    
    public func glassTextFieldStyle() -> some View {
        self.modifier(GlassTextFieldModifier())
    }
}
