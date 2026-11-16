import Cocoa
var seq: [String] = []; var sum = 0.0
let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
  eventsOfInterest: CGEventMask(1 << CGEventType.scrollWheel.rawValue), callback: { _, _, ev, _ in
    let sp = ev.getIntegerValueField(.scrollWheelEventScrollPhase), mp = ev.getIntegerValueField(.scrollWheelEventMomentumPhase)
    sum += ev.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
    let s = "s\(sp)m\(mp)"; if seq.last?.hasPrefix(s) == true { let p = seq.removeLast().split(separator: "x"); seq.append("\(s)x\((Int(p.last ?? "1") ?? 1) + (p.count > 1 ? 1 : 1))") } else { seq.append(s) }
    return Unmanaged.passUnretained(ev) }, userInfo: nil)!
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
  for _ in 0..<3 { CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0)!.post(tap: .cghidEventTap); usleep(40000) }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 3) { print(seq.joined(separator: " → "), "sum=\(sum)"); exit(0) }
CFRunLoopRun()
