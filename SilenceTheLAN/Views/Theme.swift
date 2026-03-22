import SwiftUI

// MARK: - Color Theme

extension Color {
    static let theme = ThemeColors()
}

struct ThemeColors {
    // Surfaces
    let background = Color(red: 0.043, green: 0.075, blue: 0.149)       // #0b1326 Deep Slate
    let surface = Color(red: 0.075, green: 0.106, blue: 0.180)           // #131b2e
    let surfaceElevated = Color(red: 0.176, green: 0.204, blue: 0.286)   // #2d3449

    // Brand
    let primary = Color(red: 0.145, green: 0.388, blue: 0.922)           // #2563eb
    let accent = Color(red: 0.706, green: 0.773, blue: 1.0)              // #b4c5ff

    // Status
    let success = Color(red: 0.063, green: 0.725, blue: 0.506)           // #10b981
    let warning = Color(red: 0.961, green: 0.620, blue: 0.043)           // #f59e0b
    let danger = Color(red: 0.937, green: 0.267, blue: 0.267)            // #ef4444

    // Text
    let textPrimary = Color.white
    let textSecondary = Color(red: 0.580, green: 0.639, blue: 0.722)     // #94a3b8
    let textTertiary = Color(red: 0.392, green: 0.455, blue: 0.545)      // #64748b

    // Borders & Glass
    let border = Color(red: 0.580, green: 0.639, blue: 0.722).opacity(0.15)
    let glassFill = Color.white.opacity(0.03)
}

// MARK: - Glow Modifiers

struct SoftGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.4) : .clear, radius: radius)
    }
}

extension View {
    func softGlow(_ color: Color, radius: CGFloat = 8, isActive: Bool = true) -> some View {
        modifier(SoftGlow(color: color, radius: radius, isActive: isActive))
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
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
                    .stroke(Color.theme.primary.opacity(0.2 - Double(i) * 0.05), lineWidth: 1)
                    .frame(width: 150 + CGFloat(i) * 50)
            }

            // Scanning beam
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    AngularGradient(
                        colors: [Color.theme.primary.opacity(0), Color.theme.primary],
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
                .fill(Color.theme.primary)
                .frame(width: 12)
                .softGlow(Color.theme.primary, radius: 8)

            // Pulsing circles
            Circle()
                .stroke(Color.theme.primary.opacity(0.5), lineWidth: 2)
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

// MARK: - Brand Mark

struct QuietSignalArc: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

struct QuietSignalMark: View {
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            QuietSignalArc(startAngle: .degrees(205), endAngle: .degrees(335))
                .stroke(
                    Color.theme.accent.opacity(0.3),
                    style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                )
                .frame(width: size * 1.2, height: size * 1.2)
                .offset(y: -size * 0.34)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.theme.primary, Color(red: 0.10, green: 0.30, blue: 0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .softGlow(Color.theme.primary, radius: size * 0.12)

            HStack(spacing: size * 0.12) {
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.theme.background)
                    .frame(width: size * 0.16, height: size * 0.48)

                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.theme.background)
                    .frame(width: size * 0.16, height: size * 0.48)
            }
        }
        .frame(width: size * 1.5, height: size * 1.5)
    }
}

// MARK: - Animated Button Style

struct FilledButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(color)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FilledButtonStyle {
    static func filled(_ color: Color) -> FilledButtonStyle {
        FilledButtonStyle(color: color)
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
