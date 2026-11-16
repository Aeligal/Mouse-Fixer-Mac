import Cocoa
for w in CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]] where (w[kCGWindowOwnerName as String] as? String) == "MouseFixer" || (w[kCGWindowOwnerName as String] as? String) == "Mouse Fixer" {
  if (w[kCGWindowLayer as String] as? Int) == 0 { print(w[kCGWindowNumber as String]!); break }
}
