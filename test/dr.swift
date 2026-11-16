import Cocoa
let step = Int64(CommandLine.arguments[1])!
func mouse(_ t: CGEventType, dx: Int64 = 0) {
  let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: CGMouseButton(rawValue: 3)!)!
  e.setIntegerValueField(.mouseEventDeltaX, value: dx); e.post(tap: .cghidEventTap)
}
mouse(.otherMouseDown); usleep(60000)
for _ in 0..<10 { mouse(.otherMouseDragged, dx: step); usleep(20000) }
mouse(.otherMouseUp)
