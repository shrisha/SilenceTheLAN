import SwiftUI

// MARK: - Color Theme

extension Color {
    static let theme = ThemeColors()
}

struct ThemeColors {
    // Core colors
    let background = Color.black
    let surface = Color(white: 0.08)
    let surfaceElevated = Color(white: 0.12)

    // Neon accents
    let neonGreen = Color(red: 0, green: 1, blue: 0.53) // #00FF88
    let neonRed = Color(red: 1, green: 0.27, blue: 0.27) // #FF4444
    let neonBlue = Color(red: 0.4, green: 0.6, blue: 1) // Accent blue
    let neonPurple = Color(red: 0.7, green: 0.4, blue: 1) // Accent purple
    let neonAmber = Color(red: 1, green: 0.75, blue: 0) // #FFBF00

    // Text colors
    let textPrimary = Color.white
    let textSecondary = Color(white: 0.6)
    let textTertiary = Color(white: 0.4)

    // Glass effect
    let glassStroke = Color.white.opacity(0.1)
    let glassFill = Color.white.opacity(0.05)
}

// MARK: - Glow Modifiers

struct NeonGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.8) : .clear, radius: radius)
            .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: radius * 2)
            .shadow(color: isActive ? color.opacity(0.3) : .clear, radius: radius * 3)
    }
}

extension View {
    func neonGlow(_ color: Color, radius: CGFloat = 10, isActive: Bool = true) -> some View {
        modifier(NeonGlow(color: color, radius: radius, isActive: isActive))
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.theme.glassFill)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial.opacity(0.3))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.theme.glassStroke, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if isActive {
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 2)
                        .offset(x: -geo.size.width + (phase * geo.size.width * 2))
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                phase = 1
                            }
                        }
                    }
                }
                .mask(content)
            )
    }
}

extension View {
    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerEffect(isActive: isActive))
    }
}

// MARK: - Pulse Animation

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing && isActive ? 1.02 : 1.0)
            .animation(
                isActive ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulse(isActive: Bool = true) -> some View {
        modifier(PulseAnimation(isActive: isActive))
    }
}

// MARK: - Scanning Radar Effect

struct RadarScanView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.5

    var body: some View {
        ZStack {
            // Outer rings
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.theme.neonGreen.opacity(0.2 - Double(i) * 0.05), lineWidth: 1)
                    .frame(width: 150 + CGFloat(i) * 50)
            }

            // Scanning beam
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    AngularGradient(
                        colors: [Color.theme.neonGreen.opacity(0), Color.theme.neonGreen],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(90)
                    ),
                    lineWidth: 60
                )
                .frame(width: 200)
                .rotationEffect(.degrees(rotation))

            // Center dot
            Circle()
                .fill(Color.theme.neonGreen)
                .frame(width: 12)
                .neonGlow(Color.theme.neonGreen, radius: 8)

            // Pulsing circles
            Circle()
                .stroke(Color.theme.neonGreen.opacity(0.5), lineWidth: 2)
                .frame(width: 40 * scale)
                .opacity(2 - Double(scale))
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                scale = 2
            }
        }
    }
}

// MARK: - Gradient Text

struct GradientText: View {
    let text: String
    let gradient: LinearGradient
    let font: Font

    init(_ text: String, colors: [Color], font: Font = .largeTitle) {
        self.text = text
        self.gradient = LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        self.font = font
    }

    var body: some View {
        Text(text)
            .font(font)
            .fontWeight(.black)
            .foregroundStyle(gradient)
    }
}

// MARK: - Animated Button Style

struct NeonButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.black)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(color)
            )
            .neonGlow(color, radius: configuration.isPressed ? 5 : 15)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == NeonButtonStyle {
    static func neon(_ color: Color) -> NeonButtonStyle {
        NeonButtonStyle(color: color)
    }
}

// MARK: - Secondary Button Style

struct GhostButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .stroke(color.opacity(0.5), lineWidth: 1)
                    .background(Capsule().fill(color.opacity(0.1)))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static func ghost(_ color: Color) -> GhostButtonStyle {
        GhostButtonStyle(color: color)
    }
}
