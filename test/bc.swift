import Foundation
import IOKit.hid
func mouseButtonCount() -> Int {
    let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(m, [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 2] as CFDictionary)
    guard let devs = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice> else { return 0 }
    var best = 0
    for d in devs {
        let name = IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String ?? "?"
        let els = (IOHIDDeviceCopyMatchingElements(d, [kIOHIDElementUsagePageKey: 9] as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement]) ?? []
        let top = els.map { Int(IOHIDElementGetUsage($0)) }.max() ?? 0
        print("device:", name, "buttons:", top)
        best = max(best, top)
    }
    return best
}
print("max:", mouseButtonCount())
