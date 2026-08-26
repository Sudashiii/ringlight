//
//  BrightnessControl.swift
//  ringlight
//

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
