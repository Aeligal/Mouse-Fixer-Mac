import Cocoa
var seen: [String] = []
let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
  eventsOfInterest: CGEventMask(1 << 29), callback: { _, t, ev, _ in
    seen.append("type \(t.rawValue) sub \(ev.getIntegerValueField(CGEventField(rawValue: 110)!))"); return Unmanaged.passUnretained(ev) }, userInfo: nil)!
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
  for t in [CGEventType.otherMouseDown, .otherMouseUp] { CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: CGMouseButton(rawValue: 3)!)!.post(tap: .cghidEventTap); usleep(50000) }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { print(seen.isEmpty ? "no gesture event seen" : seen.joined(separator: "\n")); exit(0) }
CFRunLoopRun()
