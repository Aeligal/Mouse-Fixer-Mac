// Offline license tool. usage:
//   license keygen                      create tools/license-private.key, print the public key to embed in main.swift
//   license sign "<name>" [YYYY-MM-DD]  print a license key (optional expiry)
import Foundation
import CryptoKit

func b64u(_ d: Data) -> String { d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
let dir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let keyFile = FileManager.default.currentDirectoryPath + "/tools/license-private.key"
let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "keygen":
    guard !FileManager.default.fileExists(atPath: keyFile) else { print("private key already exists: \(keyFile)"); exit(1) }
    let k = Curve25519.Signing.PrivateKey()
    try! k.rawRepresentation.base64EncodedString().write(toFile: keyFile, atomically: true, encoding: .utf8)
    chmod(keyFile, 0o600)
    print("public key: \(k.publicKey.rawRepresentation.base64EncodedString())")
case "sign":
    guard args.count > 2, let raw = try? String(contentsOfFile: keyFile, encoding: .utf8),
          let kd = Data(base64Encoded: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
          let k = try? Curve25519.Signing.PrivateKey(rawRepresentation: kd) else { print("usage: license sign \"<name>\" [YYYY-MM-DD]  (run keygen first, from the project root)"); exit(1) }
    let payload = try! JSONSerialization.data(withJSONObject: ["n": args[2], "e": args.count > 3 ? args[3] : ""], options: [.sortedKeys])
    print("MF1.\(b64u(payload)).\(b64u(try! k.signature(for: payload)))")
default: print("usage: license keygen | license sign \"<name>\" [YYYY-MM-DD]"); exit(1)
}
