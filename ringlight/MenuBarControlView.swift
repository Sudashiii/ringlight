//
//  MenuBarControlView.swift
//  ringlight
//

import SwiftUI
import AppKit
import AVFoundation

struct ControlSlider: View {
    let icon: String
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var unit: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(unit == "%" ? value * 100 : value))\(unit)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Slider(value: $value, in: range)
                .controlSize(.small)
        }
    }
}

struct TemperatureSlider: View {
    @Binding var value: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 18)
                Text("Temperature")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }

            GeometryReader { geometry in
                let thumbSize: CGFloat = 18
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.65, blue: 0.3),
                                    Color.white,
                                    Color(red: 0.75, green: 0.88, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 20)

                    // Unfilled ring thumb allowing track color to show through the center
                    ZStack {
                        // White ring body (unfilled in the middle)
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: thumbSize, height: thumbSize)

                        // Inner black-ish border outlining the central color hole
                        Circle()
                            .strokeBorder(Color.black.opacity(0.35), lineWidth: 0.75)
                            .frame(width: thumbSize - 5.5, height: thumbSize - 5.5)

                        // Outer black-ish border outlining the exterior ring
                        Circle()
                            .strokeBorder(Color.black.opacity(0.35), lineWidth: 0.75)
                            .frame(width: thumbSize, height: thumbSize)
                    }
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .offset(x: value * (geometry.size.width - thumbSize))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let trackWidth = geometry.size.width - thumbSize
                            guard trackWidth > 0 else { return }
                            let clampedX = min(max(gesture.location.x - thumbSize / 2, 0), trackWidth)
                            value = clampedX / trackWidth
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text("Warm")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Cool")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.layer?.cornerRadius = 8
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let session = session {
            let existingLayer = nsView.layer?.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer
            if existingLayer == nil {
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                layer.frame = nsView.bounds

                // Mirror the preview
                if let connection = layer.connection {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = true
                    }
                }

                nsView.layer?.addSublayer(layer)
            } else {
                existingLayer?.frame = nsView.bounds

                // Ensure mirroring is maintained on update
                if let connection = existingLayer?.connection {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = true
                    }
                }
            }
        } else {
            nsView.layer?.sublayers?.forEach { if $0 is AVCaptureVideoPreviewLayer { $0.removeFromSuperlayer() } }
        }
    }
}

struct MenuBarControlView: View {
    @ObservedObject var state: RingLightState

    var body: some View {
        VStack(spacing: 0) {
            // Camera Preview
            if state.showCameraPreview {
                CameraPreviewView(session: state.captureSession)
                    .frame(height: 140)
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                Divider()
            }

            // Minimal Header
            HStack {
                Text("Ring Light")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Toggle("", isOn: $state.isActive)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // Controls - No Scroll
            VStack(spacing: 12) {
                ControlSlider(icon: "sun.max.fill", label: "Brightness", value: $state.brightness, range: 0.1...1.0, unit: "%")

                TemperatureSlider(value: $state.colorTemperature)

                ControlSlider(icon: "rays", label: "Intensity", value: $state.intensity, range: 0.0...1.0, unit: "%")

                ControlSlider(icon: "sun.dust.fill", label: "Glow", value: $state.glowIntensity, range: 0.0...1.0, unit: "%")

                // Active Sides Selector
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 14)
                        Text("Active Sides")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        SideToggleButton(label: "Top", icon: "arrow.up", isOn: $state.showTopSide)
                        SideToggleButton(label: "Bottom", icon: "arrow.down", isOn: $state.showBottomSide)
                        SideToggleButton(label: "Left", icon: "arrow.left", isOn: $state.showLeftSide)
                        SideToggleButton(label: "Right", icon: "arrow.right", isOn: $state.showRightSide)
                    }
                }

                ControlSlider(icon: "rectangle.expand.vertical", label: "Thickness", value: $state.ringThickness, range: 10...100, unit: "px")

                ControlSlider(icon: "circle.circle", label: "Radius", value: $state.cornerRadius, range: 0...200, unit: "px")

                ControlSlider(icon: "arrow.up.left.and.arrow.down.right", label: "Margin", value: $state.margin, range: 0...40, unit: "px")

                HStack(spacing: 8) {
                    Toggle("", isOn: $state.avoidMouse)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .frame(width: 18)
                    Text("Avoid Mouse")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
            }
            .padding(16)

            Divider()

            // Minimal Footer
            HStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: "https://github.com/itsOmSarraf/ringlight") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Star on GitHub")
                    }
                    .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14) // More balanced padding
        }
        .frame(width: 260, height: 760)
    }
}

struct SideToggleButton: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isOn ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOn ? Color.accentColor : Color(NSColor.controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isOn ? Color.white.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
