import Cocoa
var log: [String] = []
let types: [CGEventType] = [.keyDown, .otherMouseDown, .otherMouseUp]
let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
  eventsOfInterest: mask, callback: { _, t, ev, _ in
    if t == .keyDown { log.append("key \(ev.getIntegerValueField(.keyboardEventKeycode))") }
    else { log.append("\(t == .otherMouseDown ? "down" : "up") b\(ev.getIntegerValueField(.mouseEventButtonNumber))") }
    return Unmanaged.passUnretained(ev) }, userInfo: nil)!
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
func mouse(_ t: CGEventType, _ b: CGMouseButton, dx: Int64 = 0, dy: Int64 = 0) {
  let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: b)!
  e.setIntegerValueField(.mouseEventDeltaX, value: dx); e.setIntegerValueField(.mouseEventDeltaY, value: dy)
  e.post(tap: .cghidEventTap)
}
func gesture(_ b: Int, _ dx: Int64, _ dy: Int64) {
  let btn = CGMouseButton(rawValue: UInt32(b))!
  DispatchQueue.main.async { log.append("-- b\(b) drag(\(dx),\(dy))") }
  mouse(.otherMouseDown, btn); usleep(50000)
  if dx != 0 || dy != 0 { mouse(.otherMouseDragged, btn, dx: dx, dy: dy); usleep(50000) }
  mouse(.otherMouseUp, btn); usleep(200000)
}
DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
  gesture(2, -100, 0); gesture(2, 100, 0)

}
Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in log.forEach { print($0) }; exit(0) }
CFRunLoopRun()
