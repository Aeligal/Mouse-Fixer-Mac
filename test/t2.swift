import Cocoa
var log: [String] = []
let types: [CGEventType] = [.keyDown, .otherMouseDown, .scrollWheel]
let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
  eventsOfInterest: mask, callback: { _, t, ev, _ in
    switch t {
    case .keyDown: log.append("key \(ev.getIntegerValueField(.keyboardEventKeycode))")
    case .otherMouseDown: log.append("middle-down b\(ev.getIntegerValueField(.mouseEventButtonNumber))")
    default: log.append("scroll line=\(ev.getIntegerValueField(.scrollWheelEventDeltaAxis1)) cont=\(ev.getIntegerValueField(.scrollWheelEventIsContinuous))") }
    return Unmanaged.passUnretained(ev) }, userInfo: nil)!
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
func mouse(_ t: CGEventType, _ b: Int) {
  CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: CGMouseButton(rawValue: UInt32(b))!)!.post(tap: .cghidEventTap)
}
func mark(_ s: String) { DispatchQueue.main.async { log.append("-- " + s) } }
func click(_ b: Int, hold: UInt32 = 50000) { mouse(.otherMouseDown, b); usleep(hold); mouse(.otherMouseUp, b) }
DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
  mark("b3 single click (expect c after 0.3s)"); click(3); usleep(700000)
  mark("b3 double click (expect d only)"); click(3); usleep(100000); click(3); usleep(700000)
  mark("b3 hold 0.7s (expect h only)"); click(3, hold: 700000); usleep(700000)
  mark("scroll +3 lines (expect per-profile sign)")
  CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 3, wheel2: 0, wheel3: 0)!.post(tap: .cghidEventTap); usleep(300000)
  mark("cmd+scroll +1,-1 (zoom on: keys 24 then 27)")
  for d: Int32 in [1, -1] { let e = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: d, wheel2: 0, wheel3: 0)!; e.flags = .maskCommand; e.post(tap: .cghidEventTap); usleep(200000) }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 6) { log.forEach { print($0) }; exit(0) }
CFRunLoopRun()
