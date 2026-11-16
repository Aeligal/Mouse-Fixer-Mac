import Cocoa
var n = [Int64: Int](); var offs: [String] = []
let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
  eventsOfInterest: CGEventMask(1 << 30) | CGEventMask(1 << 25), callback: { _, t, ev, _ in
    if t.rawValue == 30 { let p = ev.getIntegerValueField(CGEventField(rawValue: 132)!); n[p, default: 0] += 1
      offs.append("\(p):\(String(format: "%.2f", ev.getDoubleValueField(CGEventField(rawValue: 124)!)))") }
    return Unmanaged.passUnretained(ev) }, userInfo: nil)!
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { _ = Process.launchedProcess(launchPath: CommandLine.arguments[1], arguments: ["-30"]) }
DispatchQueue.main.asyncAfter(deadline: .now() + 2) { print("phase counts: \(n)"); print(offs.joined(separator: " ")); exit(0) }
CFRunLoopRun()
