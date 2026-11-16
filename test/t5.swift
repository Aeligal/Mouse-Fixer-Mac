import Cocoa
var log: [String] = []
let types: [CGEventType] = [.keyDown, .otherMouseDown]
let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
  eventsOfInterest: mask, callback: { _, t, ev, _ in
    log.append(t == .keyDown ? "key \(ev.getIntegerValueField(.keyboardEventKeycode))" : "otherDown b\(ev.getIntegerValueField(.mouseEventButtonNumber))")
    return Unmanaged.passUnretained(ev) }, userInfo: nil)!
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
func mouse(_ t: CGEventType, _ b: Int) { CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: CGMouseButton(rawValue: UInt32(b))!)!.post(tap: .cghidEventTap) }
func mark(_ s: String) { DispatchQueue.main.async { log.append("-- " + s) } }
DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
  mark("b3 tap then press-hold (expect key 19 only)"); mouse(.otherMouseDown, 3); usleep(40000); mouse(.otherMouseUp, 3); usleep(100000); mouse(.otherMouseDown, 3); usleep(700000); mouse(.otherMouseUp, 3); usleep(700000)
  mark("b3 single click (expect key 8 after delay)"); mouse(.otherMouseDown, 3); usleep(40000); mouse(.otherMouseUp, 3); usleep(700000)
  mark("hold b5, click b4 (expect key 7 only)"); mouse(.otherMouseDown, 5); usleep(80000); mouse(.otherMouseDown, 4); usleep(40000); mouse(.otherMouseUp, 4); usleep(80000); mouse(.otherMouseUp, 5); usleep(500000)
  mark("b4 alone (expect nothing)"); mouse(.otherMouseDown, 4); usleep(40000); mouse(.otherMouseUp, 4); usleep(300000)
  mark("b5 alone (expect key 3)"); mouse(.otherMouseDown, 5); usleep(40000); mouse(.otherMouseUp, 5); usleep(300000)
}
DispatchQueue.main.asyncAfter(deadline: .now() + 6) { log.forEach { print($0) }; exit(0) }
CFRunLoopRun()
