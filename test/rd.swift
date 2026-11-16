import Foundation
import IOKit
import IOKit.hidsystem
var v = 0.0; _ = IOHIDGetAccelerationWithKey(NXOpenEventStatus(), kIOHIDMouseAccelerationType as CFString, &v); print(v)
