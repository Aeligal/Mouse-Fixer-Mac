import Cocoa
var lineEv = 0, pixEv = 0, pixSum = 0.0
let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
  eventsOfInterest: mask, callback: { _, _, ev, _ in
    if ev.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 { lineEv += 1; pixSum += ev.getDoubleValueField(.scrollWheelEventDeltaAxis1) * 1000 }
    else { pixEv += 1; pixSum += ev.getDoubleValueField(.scrollWheelEventPointDeltaAxis1) }
    return Unmanaged.passUnretained(ev) }, userInfo: nil)!
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
let n = Int32(CommandLine.arguments.dropFirst().first ?? "3")!
Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
  for _ in 0..<3 { CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: n, wheel2: 0, wheel3: 0)!.post(tap: .cghidEventTap) }
}
Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
  print("line events: \(lineEv)  pixel events: \(pixEv)  pixel sum: \(pixSum)"); exit(0) }
CFRunLoopRun()
