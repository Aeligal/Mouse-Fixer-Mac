import Foundation
let b = Bundle(path: NSHomeDirectory() + "/Applications/Mouse Fixer.app")!
print(b.preferredLocalizations.first ?? "?", "|", b.localizedString(forKey: "Quit Mouse Fixer", value: nil, table: nil), "|", b.localizedString(forKey: "Smooth scrolling", value: nil, table: nil))
