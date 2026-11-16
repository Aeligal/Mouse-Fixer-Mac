import Cocoa
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSGetActiveSpace") func CGSGetActiveSpace(_ cid: Int32) -> Int
func space() -> Int { CGSGetActiveSpace(CGSMainConnectionID()) }
func F(_ n: UInt32) -> CGEventField { CGEventField(rawValue: n)! }
// variant: which fields to include
func post(phase: Int64, offset: Double, motion: Int64, vel: Double) {
    let g = CGEvent(source: nil)!; g.type = CGEventType(rawValue: 29)!
    g.setIntegerValueField(F(110), value: 23); g.setIntegerValueField(F(132), value: phase)   // gesture companion
    g.post(tap: .cghidEventTap)
    let d = CGEvent(source: nil)!; d.type = CGEventType(rawValue: 30)!
    d.setIntegerValueField(F(110), value: 23)
    d.setIntegerValueField(F(132), value: phase)
    d.setIntegerValueField(F(134), value: phase)
    d.setIntegerValueField(F(123), value: motion)
    d.setDoubleValueField(F(124), value: offset)
    d.setDoubleValueField(F(129), value: vel)
    d.setDoubleValueField(F(130), value: vel)
    d.post(tap: .cghidEventTap)
}
let dir = Double(CommandLine.arguments.dropFirst().first ?? "1")!   // +1 / -1
print("space before: \(space())")
post(phase: 1, offset: 0, motion: 1, vel: 0); usleep(20000)
var o = 0.0
for _ in 0..<10 { o += 0.1 * dir; post(phase: 2, offset: o, motion: 1, vel: 0); usleep(16000) }
post(phase: 4, offset: o, motion: 1, vel: dir * 2); 
for _ in 0..<10 { usleep(500000); print(space()) }
print("space after: \(space())")
