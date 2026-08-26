//
//  AppDelegate.swift
//  ringlight
//

import SwiftUI
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let state = RingLightState()

    var overlayWindow: NSWindow?
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var mouseMonitor: Any?
    var localMouseMonitor: Any?

    func startCamera() {
        if state.captureSession != nil { return }

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
                self.state.captureSession = session
            }
        }
    }

    func stopCamera() {
        state.captureSession?.stopRunning()
        state.captureSession = nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Match app brightness to system brightness on launch
        state.brightness = CGFloat(BrightnessControl.getBrightness())

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
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] _ in
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

        if state.mouseLocation != convertedLocation {
            state.mouseLocation = convertedLocation
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
        let hostingView = NSHostingView(rootView: RingLightOverlay(state: state))
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
        popover?.contentSize = NSSize(width: 260, height: 760)
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(rootView: MenuBarControlView(state: state))
    }

    func popoverWillShow(_ notification: Notification) {
        state.showCameraPreview = true
        startCamera()
    }

    func popoverDidClose(_ notification: Notification) {
        state.showCameraPreview = false
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
                self?.state.isActive.toggle()
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
