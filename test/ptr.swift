import Cocoa
import IOKit
import IOKit.hidsystem
// 1) IOKit acceleration readback (does not change anything)
let h = NXOpenEventStatus()
var cur = 0.0
let r = IOHIDGetAccelerationWithKey(h, kIOHIDMouseAccelerationType as CFString, &cur)
print("mouse accel get ret=\(r) value=\(cur)")
var tr = 0.0
print("trackpad ret=\(IOHIDGetAccelerationWithKey(h, kIOHIDTrackpadAccelerationType as CFString, &tr)) value=\(tr)")
let orig = cur
for v in [2.0, -1.0, orig] {
  let s = IOHIDSetAccelerationWithKey(h, kIOHIDMouseAccelerationType as CFString, v)
  var back = 0.0; _ = IOHIDGetAccelerationWithKey(h, kIOHIDMouseAccelerationType as CFString, &back)
  print("set \(v) ret=\(s) readback=\(back)")
}
