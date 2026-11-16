import Cocoa
var log: [String] = []
let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.scrollWheel.rawValue)
let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _, t, ev, _ in
    if t == .keyDown { log.append("key \(ev.getIntegerValueField(.keyboardEventKeycode))") }
    else if ev.getIntegerValueField(.scrollWheelEventScrollPhase) == 128 { /* real device */ }
    else { let sp = ev.getIntegerValueField(.scrollWheelEventScrollPhase); if sp != 0 && ev.getIntegerValueField(.scrollWheelEventIsContinuous) == 1 { log.append("scroll sp=\(sp) dy=\(Int(ev.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)))") } }
    return Unmanaged.passUnretained(ev) }, userInfo: nil)!
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
func mouse(_ t: CGEventType, dy: Int64 = 0) { let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: CGMouseButton(rawValue: 5)!)!; e.setIntegerValueField(.mouseEventDeltaY, value: dy); e.post(tap: .cghidEventTap) }
func mark(_ s: String) { DispatchQueue.main.async { log.append("-- " + s) } }
DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
  mark("click with 3px of hand jitter (expect key 8)"); mouse(.otherMouseDown); usleep(50000); mouse(.otherMouseDragged, dy: 2); usleep(20000); mouse(.otherMouseDragged, dy: 3); usleep(40000); mouse(.otherMouseUp); usleep(500000)
  mark("real drag 60px (expect scroll sp=1,2..,4 and NO key)"); mouse(.otherMouseDown); usleep(50000); for _ in 0..<4 { mouse(.otherMouseDragged, dy: 15); usleep(30000) }; mouse(.otherMouseUp); usleep(500000)
  mark("long hold 1.5s without moving (expect key 8 on release, button still tracked)"); mouse(.otherMouseDown); usleep(1500000); mouse(.otherMouseUp); usleep(500000)
}
DispatchQueue.main.asyncAfter(deadline: .now() + 5) { log.forEach { print($0) }; exit(0) }
CFRunLoopRun()
