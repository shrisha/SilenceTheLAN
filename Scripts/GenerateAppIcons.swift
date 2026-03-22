#!/usr/bin/env swift

// Run with: swift Scripts/GenerateAppIcons.swift
// This generates app icons for the iOS app

import SwiftUI
import AppKit
import Foundation

// MARK: - Quiet Signal Components

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

struct QuietSignalGlyph: View {
    let size: CGFloat
    let monochrome: Bool

    var body: some View {
        ZStack {
            QuietSignalArc(startAngle: .degrees(205), endAngle: .degrees(335))
                .stroke(
                    monochrome ? Color.white.opacity(0.35) : Color(red: 0.706, green: 0.773, blue: 1.0).opacity(0.3),
                    style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                )
                .frame(width: size * 1.2, height: size * 1.2)
                .offset(y: -size * 0.34)

            Circle()
                .fill(
                    monochrome
                    ? AnyShapeStyle(Color.white.opacity(0.88))
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.145, green: 0.388, blue: 0.922),  // #2563eb
                                Color(red: 0.10, green: 0.30, blue: 0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .frame(width: size, height: size)
                .shadow(
                    color: monochrome ? .clear : Color(red: 0.145, green: 0.388, blue: 0.922).opacity(0.4),
                    radius: size * 0.12
                )

            HStack(spacing: size * 0.12) {
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(monochrome ? Color.black : Color(red: 0.043, green: 0.075, blue: 0.149))
                    .frame(width: size * 0.16, height: size * 0.48)

                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(monochrome ? Color.black : Color(red: 0.043, green: 0.075, blue: 0.149))
                    .frame(width: size * 0.16, height: size * 0.48)
            }
        }
    }
}

// MARK: - App Icon Variants

struct AppIconMain: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                Rectangle()
                    .fill(Color(red: 0.043, green: 0.075, blue: 0.149))  // #0b1326

                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.075, green: 0.106, blue: 0.180),  // #131b2e
                                Color(red: 0.043, green: 0.075, blue: 0.149)   // #0b1326
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.145, green: 0.388, blue: 0.922).opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size * 0.92, height: size * 0.92)

                QuietSignalGlyph(size: size * 0.46, monochrome: false)
                    .offset(y: size * 0.03)
            }
        }
    }
}

struct AppIconTinted: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                Rectangle()
                    .fill(Color.black)

                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color.black)

                QuietSignalGlyph(size: size * 0.46, monochrome: true)
                    .offset(y: size * 0.03)
            }
        }
    }
}

// MARK: - Export Functions

@MainActor
func exportIcon<V: View>(_ view: V, to path: String) {
    let size: CGFloat = 1024
    let framedView = view.frame(width: size, height: size)

    let renderer = ImageRenderer(content: framedView)
    renderer.scale = 1.0

    guard let nsImage = renderer.nsImage,
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: Int(size),
            height: Int(size),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else {
        print("❌ Failed to render image")
        return
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

    guard let flattenedImage = context.makeImage() else {
        print("❌ Failed to flatten icon")
        return
    }

    let bitmap = NSBitmapImageRep(cgImage: flattenedImage)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("❌ Failed to encode PNG")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("✅ Exported: \(path)")
    } catch {
        print("❌ Failed to write \(path): \(error)")
    }
}

// MARK: - Main

@MainActor
func generateIcons() async {
    // Get the directory containing this script
    let scriptPath = CommandLine.arguments[0]
    let scriptURL = URL(fileURLWithPath: scriptPath)
    let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    let assetPath = projectRoot.appendingPathComponent("SilenceTheLAN/Assets.xcassets/AppIcon.appiconset")

    print("🎨 Generating app icons...")
    print("📁 Output directory: \(assetPath.path)")

    // Create directory if needed
    try? FileManager.default.createDirectory(at: assetPath, withIntermediateDirectories: true)

    // Export default icon
    exportIcon(AppIconMain(), to: assetPath.appendingPathComponent("AppIcon.png").path)

    // Export dark icon
    exportIcon(AppIconMain(), to: assetPath.appendingPathComponent("AppIcon-Dark.png").path)

    // Export tinted icon
    exportIcon(AppIconTinted(), to: assetPath.appendingPathComponent("AppIcon-Tinted.png").path)

    print("✨ Done! App icons generated successfully.")
}

// Entry point - run async on main actor
Task { @MainActor in
    await generateIcons()
    exit(0)
}

// Keep the script running until the Task completes
RunLoop.main.run()
