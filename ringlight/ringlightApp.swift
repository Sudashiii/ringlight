//
//  ringlightApp.swift
//  ringlight
//
//  Created by Om Sarraf on 20/12/25.
//

import SwiftUI
import AppKit
import AVFoundation
import CoreMediaIO
import CoreGraphics

// Brightness control helper using dynamic loading
class BrightnessControl {
    typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    
    private static var setBrightnessFunc: SetBrightnessFunc?
    private static var getBrightnessFunc: GetBrightnessFunc?
    private static var isLoaded = false
    
    static func loadDisplayServices() {
        guard !isLoaded else { return }
        isLoaded = true
        
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
        if handle != nil {
            if let setBrightness = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessFunc = unsafeBitCast(setBrightness, to: SetBrightnessFunc.self)
            }
            if let getBrightness = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightnessFunc = unsafeBitCast(getBrightness, to: GetBrightnessFunc.self)
            }
        }
    }
    
    static func setBrightness(_ level: Float) {
        loadDisplayServices()
        if let setFunc = setBrightnessFunc {
            _ = setFunc(CGMainDisplayID(), level)
        }
    }
    
    static func getBrightness() -> Float {
        loadDisplayServices()
        var level: Float = 1.0
        if let getFunc = getBrightnessFunc {
            _ = getFunc(CGMainDisplayID(), &level)
        }
        return level
    }
}

@main
struct ringlightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSPopoverDelegate {
    var overlayWindow: NSWindow?
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var mouseMonitor: Any?
    var localMouseMonitor: Any?
    
    @Published var ringThickness: CGFloat = 45
    @Published var brightness: CGFloat = 1.0 {
        didSet {
            setSystemBrightness(Float(brightness))
        }
    }
    @Published var colorTemperature: CGFloat = 0.5
    @Published var cornerRadius: CGFloat = 80
    @Published var glowIntensity: CGFloat = 0.5
    @Published var intensity: CGFloat = 1.0
    @Published var isActive: Bool = true
    @Published var avoidMouse: Bool = true
    @Published var showCameraPreview: Bool = false
    @Published var margin: CGFloat = 8
    @Published var mouseLocation: CGPoint = .zero
    @Published var isMouseOverRing: Bool = false
    
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
    
    var ringColor: NSColor {
        temperatureToColor(colorTemperature)
    }
    
    func temperatureToColor(_ temp: CGFloat) -> NSColor {
        if temp < 0.5 {
            let w = (0.5 - temp) / 0.5
            let r: CGFloat = 1.0
            let g: CGFloat = 1.0 - (0.35 * w)
            let b: CGFloat = 1.0 - (0.75 * w)
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        } else {
            let c = (temp - 0.5) / 0.5
            let r: CGFloat = 1.0 - (0.35 * c)
            let g: CGFloat = 1.0 - (0.15 * c)
            let b: CGFloat = 1.0
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        }
    }
    
    func startCamera() {
        if captureSession != nil { return }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async {
                self.captureSession = session
            }
        }
    }
    
    func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
    }
    
    func updatePopoverSize() {
        popover?.contentSize = NSSize(width: 260, height: 700)
    }
    
    func setSystemBrightness(_ level: Float) {
        BrightnessControl.setBrightness(level)
    }
    
    func getSystemBrightness() -> Float {
        return BrightnessControl.getBrightness()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Match app brightness to system brightness on launch
        self.brightness = CGFloat(getSystemBrightness())
        
        // Hide dock icon - make it a pure menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        NSApplication.shared.windows.forEach { $0.close() }
        createOverlayWindow()
        createMenuBarIcon()
        setupGlobalKeyboardShortcuts()
        setupMouseTracking()
        updateMouseLocation()
    }
    
    func setupMouseTracking() {
        let eventMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        // Track mouse globally
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.updateMouseLocation()
        }
        // Also track locally for when the app is active
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.updateMouseLocation()
            return event
        }
    }
    
    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let localMonitor = localMouseMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
    
    func updateMouseLocation() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        
        // Convert from screen coordinates (bottom-left) to SwiftUI (top-left)
        let screenFrame = screen.frame
        let convertedLocation = CGPoint(
            x: location.x - screenFrame.origin.x,
            y: screenFrame.height - (location.y - screenFrame.origin.y)
        )
        
        if self.mouseLocation != convertedLocation {
            self.mouseLocation = convertedLocation
        }
    }
    
    func createOverlayWindow() {
        guard let screen = NSScreen.main else { return }
        let fullFrame = screen.frame
        overlayWindow = OverlayWindow(
            contentRect: fullFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        guard let window = overlayWindow else { return }
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let hostingView = NSHostingView(rootView: RingLightOverlay(appDelegate: self))
        hostingView.frame = fullFrame
        window.contentView = hostingView
        window.orderFrontRegardless()
    }
    
    func createMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // Create a custom Rectangular Ring Light icon for the menu bar
            let size = NSSize(width: 20, height: 16)
            let image = NSImage(size: size, flipped: false) { rect in
                let inset: CGFloat = 2
                let thickness: CGFloat = 2.0
                let outerRect = rect.insetBy(dx: inset, dy: inset)
                
                // Draw a rounded rectangular ring to match the app's look
                let path = NSBezierPath(roundedRect: outerRect, xRadius: 3, yRadius: 3)
                path.lineWidth = thickness
                NSColor.labelColor.setStroke()
                path.stroke()
                
                return true
            }
            image.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 260, height: 700)
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(rootView: MenuBarControlView(appDelegate: self))
    }
    
    func popoverWillShow(_ notification: Notification) {
        showCameraPreview = true
        startCamera()
        updatePopoverSize()
    }
    
    func popoverDidClose(_ notification: Notification) {
        showCameraPreview = false
        stopCamera()
    }
    
    @objc func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func setupGlobalKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            switch event.keyCode {
            case 53: // ESC
                NSApplication.shared.terminate(nil)
                return nil
            case 49: // SPACE
                self?.isActive.toggle()
                return nil
            default:
                return event
            }
        }
    }
}

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Components
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

// MARK: - Views
struct RingLightOverlay: View {
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        GeometryReader { geometry in
            if appDelegate.isActive {
                let menuBarHeight = getMenuBarHeight()
                let palette = appDelegate.colorPalette
                let brightness = appDelegate.brightness
                let glow = appDelegate.glowIntensity
                let intensity = appDelegate.intensity
                let T = appDelegate.ringThickness
                
                ZStack {
                    // 1. Wide Atmospheric Ambient Glow (Unmasked)
                    // Casts soft, warm ambient light deep into the room and screen interior.
                    // Kept unmasked so the screen background is never carved or bitten into.
                    if glow > 0 {
                        // Broad outer atmospheric dispersion (casts rich warm ambient light deep into the room)
                        RoundedRingShape(
                            thickness: T + 35 * glow,
                            cornerRadius: appDelegate.cornerRadius,
                            margin: max(0, appDelegate.margin - 17 * glow),
                            topOffset: menuBarHeight
                        )
                        .fill(palette.base.opacity(brightness * glow * 0.45))
                        .blur(radius: 40 + 50 * glow)
                        
                        // Atmospheric radiance wash (fills the room/screen with radiant golden warmth)
                        RoundedRingShape(
                            thickness: T + 20 * glow,
                            cornerRadius: appDelegate.cornerRadius,
                            margin: max(0, appDelegate.margin - 10 * glow),
                            topOffset: menuBarHeight
                        )
                        .fill(palette.mid.opacity(brightness * glow * (0.30 + 0.50 * intensity)))
                        .blur(radius: 20 + 25 * glow)
                    }
                    
                    // 2. Ring Light Structure (Masked with generous reveal radius & strong center clearing)
                    // Multi-tier gradient emission: rich amber base -> radiant golden-yellow mid -> warm luminous core
                    ZStack {
                        if glow > 0 {
                            // Radiant bloom halo wrapping the ring
                            RoundedRingShape(
                                thickness: T + 10 * glow,
                                cornerRadius: appDelegate.cornerRadius,
                                margin: max(0, appDelegate.margin - 5 * glow),
                                topOffset: menuBarHeight
                            )
                            .fill(palette.mid.opacity(brightness * glow * (0.40 + 0.50 * intensity)))
                            .blur(radius: 8 + 14 * glow)
                            
                            // Tight edge perimeter bloom
                            RoundedRingShape(
                                thickness: T + 3 * glow,
                                cornerRadius: appDelegate.cornerRadius,
                                margin: max(0, appDelegate.margin - 1.5 * glow),
                                topOffset: menuBarHeight
                            )
                            .fill(palette.base.opacity(brightness * glow * 0.85))
                            .blur(radius: 3 + 5 * glow)
                        }
                        
                        // Main illuminated ring base
                        RoundedRingShape(
                            thickness: T,
                            cornerRadius: appDelegate.cornerRadius,
                            margin: appDelegate.margin,
                            topOffset: menuBarHeight
                        )
                        .fill(palette.base.opacity(brightness))
                        .blur(radius: glow > 0 ? min(2.0, 2.0 * glow) : 0)
                        
                        // Radiant golden mid-band gradient (gives the rich, prominent yellowness across the band)
                        if intensity > 0 && T > 8 {
                            let midThickness = T * (0.50 + 0.30 * intensity)
                            let inset = (T - midThickness) / 2
                            RoundedRingShape(
                                thickness: midThickness,
                                cornerRadius: max(0, appDelegate.cornerRadius - inset),
                                margin: appDelegate.margin + inset,
                                topOffset: menuBarHeight
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
                                cornerRadius: max(0, appDelegate.cornerRadius - inset),
                                margin: appDelegate.margin + inset,
                                topOffset: menuBarHeight
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
                                cornerRadius: max(0, appDelegate.cornerRadius - inset),
                                margin: appDelegate.margin + inset,
                                topOffset: menuBarHeight
                            )
                            .fill(Color.white.opacity(brightness * intensity * (0.55 + 0.40 * glow)))
                            .blur(radius: 0.8 + 1.2 * glow)
                        }
                    }
                    .mask(
                        Group {
                            if appDelegate.avoidMouse {
                                Canvas { context, size in
                                    // Start with a fully opaque mask
                                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                                    
                                    let mousePos = appDelegate.mouseLocation
                                    let eraseRadius: CGFloat = 260
                                    
                                    // Smoothstep transition with strong clear core (60 pt) and generous 260 pt radius
                                    let gradient = Gradient(stops: [
                                        .init(color: .white, location: 0.00),        // 100% cleared
                                        .init(color: .white, location: 0.23),        // 100% cleared up to 60 pt from cursor
                                        .init(color: .white.opacity(0.93), location: 0.35),
                                        .init(color: .white.opacity(0.80), location: 0.45),
                                        .init(color: .white.opacity(0.57), location: 0.58),
                                        .init(color: .white.opacity(0.31), location: 0.72),
                                        .init(color: .white.opacity(0.11), location: 0.85),
                                        .init(color: .white.opacity(0.02), location: 0.94),
                                        .init(color: .clear, location: 1.00)         // fully restored at 260 pt
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

struct RoundedRingShape: Shape {
    var thickness: CGFloat
    var cornerRadius: CGFloat
    var margin: CGFloat
    var topOffset: CGFloat = 0
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(thickness, cornerRadius) }
        set {
            thickness = newValue.first
            cornerRadius = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let outerRect = CGRect(
            x: rect.minX + margin,
            y: rect.minY + margin + topOffset,
            width: max(0, rect.width - margin * 2),
            height: max(0, rect.height - margin * 2 - topOffset)
        )
        path.addRoundedRect(in: outerRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        let innerRect = CGRect(
            x: rect.minX + margin + thickness,
            y: rect.minY + margin + thickness + topOffset,
            width: max(0, rect.width - (margin + thickness) * 2),
            height: max(0, rect.height - (margin + thickness) * 2 - topOffset)
        )
        let innerCornerRadius: CGFloat
        if cornerRadius > thickness {
            innerCornerRadius = cornerRadius - thickness
        } else {
            innerCornerRadius = max(0, cornerRadius * 0.4)
        }
        path.addRoundedRect(in: innerRect, cornerSize: CGSize(width: innerCornerRadius, height: innerCornerRadius))
        return path
    }
}

extension RoundedRingShape {
    func fill(_ content: some ShapeStyle) -> some View {
        self.fill(content, style: FillStyle(eoFill: true))
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
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack(spacing: 0) {
            // Camera Preview
            if appDelegate.showCameraPreview {
                CameraPreviewView(session: appDelegate.captureSession)
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
                Toggle("", isOn: $appDelegate.isActive)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            Divider()
            
            // Controls - No Scroll
            VStack(spacing: 12) {
                ControlSlider(icon: "sun.max.fill", label: "Brightness", value: $appDelegate.brightness, range: 0.1...1.0, unit: "%")
                
                TemperatureSlider(value: $appDelegate.colorTemperature)
                
                ControlSlider(icon: "rays", label: "Intensity", value: $appDelegate.intensity, range: 0.0...1.0, unit: "%")
                
                ControlSlider(icon: "sun.dust.fill", label: "Glow", value: $appDelegate.glowIntensity, range: 0.0...1.0, unit: "%")
                
                ControlSlider(icon: "rectangle.expand.vertical", label: "Thickness", value: $appDelegate.ringThickness, range: 10...100, unit: "px")
                
                ControlSlider(icon: "circle.circle", label: "Radius", value: $appDelegate.cornerRadius, range: 0...200, unit: "px")
                
                ControlSlider(icon: "arrow.up.left.and.arrow.down.right", label: "Margin", value: $appDelegate.margin, range: 0...40, unit: "px")
                
                HStack(spacing: 8) {
                    Toggle("", isOn: $appDelegate.avoidMouse)
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
        .frame(width: 260, height: 700)
    }
}
