//
//  RingLightOverlay.swift
//  ringlight
//

import SwiftUI
import AppKit

struct RingLightOverlay: View {
    @ObservedObject var state: RingLightState

    var body: some View {
        GeometryReader { _ in
            if state.isActive {
                let menuBarHeight = getMenuBarHeight()
                let palette = state.colorPalette
                let brightness = state.brightness
                let glow = state.glowIntensity
                let intensity = state.intensity
                let T = state.ringThickness
                let showTop = state.showTopSide
                let showBottom = state.showBottomSide
                let showLeft = state.showLeftSide
                let showRight = state.showRightSide

                ZStack {
                    // 1. Wide Atmospheric Ambient Glow & Radiance Wash
                    if glow > 0 {
                        // Broad outer atmospheric dispersion (casts rich warm ambient light deep into the room)
                        RoundedRingShape(
                            thickness: T + 35 * glow,
                            cornerRadius: state.cornerRadius,
                            margin: max(0, state.margin - 17 * glow),
                            topOffset: menuBarHeight,
                            showTop: showTop,
                            showBottom: showBottom,
                            showLeft: showLeft,
                            showRight: showRight
                        )
                        .fill(palette.base.opacity(brightness * glow * 0.45))
                        .blur(radius: 40 + 50 * glow)

                        // Atmospheric radiance wash (fills the room/screen with radiant golden warmth)
                        RoundedRingShape(
                            thickness: T + 20 * glow,
                            cornerRadius: state.cornerRadius,
                            margin: max(0, state.margin - 10 * glow),
                            topOffset: menuBarHeight,
                            showTop: showTop,
                            showBottom: showBottom,
                            showLeft: showLeft,
                            showRight: showRight
                        )
                        .fill(palette.mid.opacity(brightness * glow * (0.30 + 0.50 * intensity)))
                        .blur(radius: 20 + 25 * glow)
                    }

                    // 2. Ring Light Bloom & Structure
                    if glow > 0 {
                        // Radiant bloom halo wrapping the ring
                        RoundedRingShape(
                            thickness: T + 10 * glow,
                            cornerRadius: state.cornerRadius,
                            margin: max(0, state.margin - 5 * glow),
                            topOffset: menuBarHeight,
                            showTop: showTop,
                            showBottom: showBottom,
                            showLeft: showLeft,
                            showRight: showRight
                        )
                        .fill(palette.mid.opacity(brightness * glow * (0.40 + 0.50 * intensity)))
                        .blur(radius: 8 + 14 * glow)

                        // Tight edge perimeter bloom
                        RoundedRingShape(
                            thickness: T + 3 * glow,
                            cornerRadius: state.cornerRadius,
                            margin: max(0, state.margin - 1.5 * glow),
                            topOffset: menuBarHeight,
                            showTop: showTop,
                            showBottom: showBottom,
                            showLeft: showLeft,
                            showRight: showRight
                        )
                        .fill(palette.base.opacity(brightness * glow * 0.85))
                        .blur(radius: 3 + 5 * glow)
                    }

                    // Main illuminated ring base
                    RoundedRingShape(
                        thickness: T,
                        cornerRadius: state.cornerRadius,
                        margin: state.margin,
                        topOffset: menuBarHeight,
                        showTop: showTop,
                        showBottom: showBottom,
                        showLeft: showLeft,
                        showRight: showRight
                    )
                    .fill(palette.base.opacity(brightness))
                    .blur(radius: glow > 0 ? min(2.0, 2.0 * glow) : 0)

                    // Radiant golden mid-band gradient (gives the rich, prominent yellowness across the band)
                    if intensity > 0 && T > 8 {
                        let midThickness = T * (0.50 + 0.30 * intensity)
                        let inset = (T - midThickness) / 2
                        RoundedRingShape(
                            thickness: midThickness,
                            cornerRadius: max(0, state.cornerRadius - inset),
                            margin: state.margin + inset,
                            topOffset: menuBarHeight,
                            showTop: showTop,
                            showBottom: showBottom,
                            showLeft: showLeft,
                            showRight: showRight
                        )
                        .fill(palette.mid.opacity(brightness * intensity * (0.45 + 0.50 * glow)))
                        .blur(radius: 2.0 + 3.5 * glow)
                    }

                    // Luminous incandescent core (creamy warm-white brilliance)
                    if intensity > 0 && T > 12 {
                        let coreThickness = T * (0.32 + 0.22 * intensity)
                        let inset = (T - coreThickness) / 2
                        RoundedRingShape(
                            thickness: coreThickness,
                            cornerRadius: max(0, state.cornerRadius - inset),
                            margin: state.margin + inset,
                            topOffset: menuBarHeight,
                            showTop: showTop,
                            showBottom: showBottom,
                            showLeft: showLeft,
                            showRight: showRight
                        )
                        .fill(palette.core.opacity(brightness * intensity * (0.50 + 0.45 * glow)))
                        .blur(radius: 1.2 + 2.2 * glow)
                    }

                    // White-hot filament center spine
                    if intensity > 0 && T > 16 {
                        let spineThickness = T * (0.14 + 0.12 * intensity)
                        let inset = (T - spineThickness) / 2
                        RoundedRingShape(
                            thickness: spineThickness,
                            cornerRadius: max(0, state.cornerRadius - inset),
                            margin: state.margin + inset,
                            topOffset: menuBarHeight,
                            showTop: showTop,
                            showBottom: showBottom,
                            showLeft: showLeft,
                            showRight: showRight
                        )
                        .fill(Color.white.opacity(brightness * intensity * (0.55 + 0.40 * glow)))
                        .blur(radius: 0.8 + 1.2 * glow)
                    }
                }
                .mask(
                    Group {
                        if state.avoidMouse {
                            Canvas { context, size in
                                // Start with a fully opaque mask
                                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

                                let mousePos = state.mouseLocation
                                let eraseRadius: CGFloat = 300

                                // Ultra-smooth quintic smootherstep (C2 continuous) radial gradient
                                // Smoothly clears both the ring light and the interior leaking glow around the cursor,
                                // with zero visible edges, circular outlines, or abrupt transitions.
                                let gradient = Gradient(stops: [
                                    .init(color: .white, location: 0.00),        // 100% cleared directly at cursor
                                    .init(color: .white, location: 0.16),        // 100% cleared core (~48 pt)
                                    .init(color: .white.opacity(0.98), location: 0.26),
                                    .init(color: .white.opacity(0.90), location: 0.38),
                                    .init(color: .white.opacity(0.74), location: 0.50),
                                    .init(color: .white.opacity(0.52), location: 0.62),
                                    .init(color: .white.opacity(0.30), location: 0.74),
                                    .init(color: .white.opacity(0.12), location: 0.85),
                                    .init(color: .white.opacity(0.02), location: 0.94),
                                    .init(color: .clear, location: 1.00)         // 0% cleared beyond 300 pt
                                ])

                                context.blendMode = .destinationOut
                                context.fill(
                                    Path(ellipseIn: CGRect(
                                        x: mousePos.x - eraseRadius,
                                        y: mousePos.y - eraseRadius,
                                        width: eraseRadius * 2,
                                        height: eraseRadius * 2
                                    )),
                                    with: .radialGradient(
                                        gradient,
                                        center: mousePos,
                                        startRadius: 0,
                                        endRadius: eraseRadius
                                    )
                                )
                            }
                        } else {
                            Rectangle().fill(Color.white)
                        }
                    }
                )
            }
        }
        .ignoresSafeArea()
    }

    func getMenuBarHeight() -> CGFloat {
        guard let screen = NSScreen.main else { return 25 }
        let calculatedHeight = screen.frame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y
        if calculatedHeight > 0 {
            return calculatedHeight
        }
        return NSStatusBar.system.thickness
    }
}
