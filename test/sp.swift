import Cocoa
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSGetActiveSpace") func CGSGetActiveSpace(_ cid: Int32) -> Int
print(CGSGetActiveSpace(CGSMainConnectionID()))
