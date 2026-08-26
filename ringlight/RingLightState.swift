//
//  RingLightState.swift
//  ringlight
//

import SwiftUI
import AVFoundation

final class RingLightState: ObservableObject {
    @Published var ringThickness: CGFloat = 45
    @Published var brightness: CGFloat = 1.0 {
        didSet {
            BrightnessControl.setBrightness(Float(brightness))
        }
    }
    @Published var colorTemperature: CGFloat = 0.5
    @Published var cornerRadius: CGFloat = 80
    @Published var glowIntensity: CGFloat = 0.5
    @Published var intensity: CGFloat = 1.0
    @Published var isActive: Bool = true
    @Published var showTopSide: Bool = true
    @Published var showBottomSide: Bool = true
    @Published var showLeftSide: Bool = true
    @Published var showRightSide: Bool = true
    @Published var avoidMouse: Bool = true
    @Published var showCameraPreview: Bool = false
    @Published var margin: CGFloat = 8
    @Published var mouseLocation: CGPoint = .zero

    var captureSession: AVCaptureSession?

    struct RingColorPalette {
        let base: Color
        let mid: Color
        let core: Color
    }

    var colorPalette: RingColorPalette {
        let temp = colorTemperature
        if temp < 0.5 {
            // Warm side: rich golden-amber to neutral white
            let w = (0.5 - temp) / 0.5
            let baseColor = Color(
                red: 1.0,
                green: 1.0 - 0.40 * w,
                blue: 1.0 - 0.88 * w
            )
            let midColor = Color(
                red: 1.0,
                green: 1.0 - 0.14 * w,
                blue: 1.0 - 0.70 * w
            )
            let coreColor = Color(
                red: 1.0,
                green: 1.0 - 0.03 * w,
                blue: 1.0 - 0.14 * w
            )
            return RingColorPalette(base: baseColor, mid: midColor, core: coreColor)
        } else {
            // Cool side: neutral white to crisp sky ice-blue
            let c = (temp - 0.5) / 0.5
            let baseColor = Color(
                red: 1.0 - 0.48 * c,
                green: 1.0 - 0.20 * c,
                blue: 1.0
            )
            let midColor = Color(
                red: 1.0 - 0.28 * c,
                green: 1.0 - 0.10 * c,
                blue: 1.0
            )
            let coreColor = Color(
                red: 1.0 - 0.08 * c,
                green: 1.0 - 0.03 * c,
                blue: 1.0
            )
            return RingColorPalette(base: baseColor, mid: midColor, core: coreColor)
        }
    }
}
