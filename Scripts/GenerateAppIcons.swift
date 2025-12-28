#!/usr/bin/env swift

// Run with: swift Scripts/GenerateAppIcons.swift
// This generates app icons for the iOS app

import SwiftUI
import AppKit
import Foundation

// MARK: - Icon Components (duplicated from iOS for standalone script)

struct Arc: Shape {
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

struct WiFiSymbol: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Arc(startAngle: .degrees(225), endAngle: .degrees(315))
                    .stroke(style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                    .frame(width: size * (0.3 + CGFloat(i) * 0.3), height: size * (0.3 + CGFloat(i) * 0.3))
                    .offset(y: size * 0.15)
            }
            Circle()
                .frame(width: size * 0.15, height: size * 0.15)
                .offset(y: size * 0.3)
        }
    }
}

// MARK: - Main Icon (Concept 2: Pause Network)

struct AppIconMain: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.08, blue: 0.12),
                                Color(red: 0.02, green: 0.02, blue: 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0, green: 1, blue: 0.53).opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.6
                        )
                    )

                // WiFi waves (faded)
                WiFiSymbol(size: size * 0.55)
                    .foregroundColor(Color.white.opacity(0.15))
                    .offset(y: -size * 0.08)

                // Pause button circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0, green: 1, blue: 0.53),
                                Color(red: 0, green: 0.7, blue: 0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.45, height: size * 0.45)
                    .shadow(color: Color(red: 0, green: 1, blue: 0.53).opacity(0.5), radius: 15)

                // Pause bars
                HStack(spacing: size * 0.05) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.05, green: 0.05, blue: 0.1))
                        .frame(width: size * 0.07, height: size * 0.18)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.05, green: 0.05, blue: 0.1))
                        .frame(width: size * 0.07, height: size * 0.18)
                }
            }
        }
    }
}

// MARK: - Tinted Icon (Monochrome)

struct AppIconTinted: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // Solid background
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color.black)

                // WiFi waves
                WiFiSymbol(size: size * 0.55)
                    .foregroundColor(Color.white.opacity(0.3))
                    .offset(y: -size * 0.08)

                // Pause button circle
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.45, height: size * 0.45)

                // Pause bars
                HStack(spacing: size * 0.05) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black)
                        .frame(width: size * 0.07, height: size * 0.18)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black)
                        .frame(width: size * 0.07, height: size * 0.18)
                }
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

    if let nsImage = renderer.nsImage {
        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: URL(fileURLWithPath: path))
                print("✅ Exported: \(path)")
            } catch {
                print("❌ Failed to write \(path): \(error)")
            }
        }
    } else {
        print("❌ Failed to render image")
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

    // Export main icon
    exportIcon(AppIconMain(), to: assetPath.appendingPathComponent("AppIcon.png").path)

    // Export dark icon (same as main for this design)
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
