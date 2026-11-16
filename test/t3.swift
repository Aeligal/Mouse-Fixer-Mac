import Cocoa
var log: [String] = []
let types: [CGEventType] = [.keyDown, .otherMouseDown, .rightMouseDown, .scrollWheel, CGEventType(rawValue: 29)!]
let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
  eventsOfInterest: mask, callback: { _, t, ev, _ in
    switch t.rawValue {
    case 10: log.append("key \(ev.getIntegerValueField(.keyboardEventKeycode))")
    case 25: log.append("otherDown b\(ev.getIntegerValueField(.mouseEventButtonNumber))")
    case 3: log.append("RIGHT-DOWN")
    case 22: log.append("scroll cont=\(ev.getIntegerValueField(.scrollWheelEventIsContinuous)) dy=\(Int(ev.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))) sp=\(ev.getIntegerValueField(.scrollWheelEventScrollPhase))")
    default:
      let sub = ev.getIntegerValueField(CGEventField(rawValue: 110)!)
      if sub == 5 || sub == 8 { log.append("gesture sub=\(sub) phase=\(ev.getIntegerValueField(CGEventField(rawValue: 132)!)) val=\(ev.getDoubleValueField(CGEventField(rawValue: sub == 8 ? 113 : 114)!))") } }
    return Unmanaged.passUnretained(ev) }, userInfo: nil)!
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
func mouse(_ t: CGEventType, _ b: Int, dy: Int64 = 0) {
  let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: CGMouseButton(rawValue: UInt32(b))!)!
  e.setIntegerValueField(.mouseEventDeltaY, value: dy); e.post(tap: .cghidEventTap)
}
func scroll(_ d: Int32, _ f: CGEventFlags = []) { let e = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: d, wheel2: 0, wheel3: 0)!; e.flags = f; e.post(tap: .cghidEventTap) }
func mark(_ s: String) { DispatchQueue.main.async { log.append("-- " + s) } }
DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
  mark("triple click b3 (expect key 17 only)"); for _ in 0..<3 { mouse(.otherMouseDown, 3); usleep(30000); mouse(.otherMouseUp, 3); usleep(80000) }; usleep(600000)
  mark("b4 held + wheel (expect rotate gesture, no click)"); mouse(.otherMouseDown, 4); usleep(80000); scroll(1); usleep(30000); scroll(1); usleep(400000); mouse(.otherMouseUp, 4); usleep(500000)
  mark("ctrl+wheel (kZoom=control: expect zoom gesture)"); scroll(1, .maskControl); usleep(500000)
  mark("cmd+wheel (kRotate=command: expect rotate gesture)"); scroll(-1, .maskCommand); usleep(500000)
  mark("b5 drag-scroll dy=30 x3"); mouse(.otherMouseDown, 5); usleep(60000); for _ in 0..<3 { mouse(.otherMouseDragged, 5, dy: 30); usleep(50000) }; mouse(.otherMouseUp, 5); usleep(500000)
  mark("b6 click (expect right click)"); mouse(.otherMouseDown, 6); usleep(40000); mouse(.otherMouseUp, 6); usleep(300000)
}
DispatchQueue.main.asyncAfter(deadline: .now() + 9) { log.forEach { print($0) }; exit(0) }
CFRunLoopRun()
