import Cocoa
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSCopyManagedDisplaySpaces") func CGSCopyManagedDisplaySpaces(_ cid: Int32) -> CFArray
for d in CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as! [[String: Any]] {
  let ids = (d["Spaces"] as! [[String: Any]]).map { "\($0["ManagedSpaceID"]!)" + ((($0["type"] as? Int) ?? 0) == 4 ? "F" : "") }
  print("display:", ids.joined(separator: " "), "current:", (d["Current Space"] as! [String: Any])["ManagedSpaceID"]!)
}
