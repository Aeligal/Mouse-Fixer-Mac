import Cocoa
let p = CGEvent(source: nil)!.location
for w in CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]] where (w[kCGWindowLayer as String] as? Int) == 0 {
  let r = CGRect(dictionaryRepresentation: w[kCGWindowBounds as String] as! NSDictionary)!
  if r.contains(p) { print(NSRunningApplication(processIdentifier: w[kCGWindowOwnerPID as String] as! pid_t)?.bundleIdentifier ?? "?"); break }
}
