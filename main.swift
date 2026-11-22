import Cocoa
import SwiftUI
import ServiceManagement
import Combine
import IOKit
import IOKit.hidsystem
import UniformTypeIdentifiers

/// Localized UI string; keys are the English text (see l10n/gen.py).
func L(_ s: String) -> String { NSLocalizedString(s, comment: "") }

// MARK: - Config

enum Act: String, Codable, CaseIterable, Identifiable {
    case none, click, missionControl, appExpose, launchpad, showDesktop
    case spaceLeft, spaceRight, back, forward, lookUp, screenshot
    case zoomIn, zoomOut, smartZoom, shortcut
    case secondaryClick, appSwitcher, dragScroll
    case primaryClick, middleClick
    case swipeSpaceLeft, swipeSpaceRight, swipeMissionControl, swipeAppExpose, swipeDesktop, swipeLaunchpad, dragSpaces, swipeBack, swipeForward
    case playPause, nextTrack, prevTrack, volumeUp, volumeDown, mute, brightnessUp, brightnessDown
    var id: String { rawValue }
    /// Names the original app uses (Buttons tab).
    var simple: String {
        switch self {
        case .appExpose: L("Application Windows")
        case .spaceLeft: L("Move Left a Space")
        case .spaceRight: L("Move Right a Space")
        case .lookUp: L("Look Up & Quick Look")
        case .shortcut: L("Keyboard Shortcut...")
        case .smartZoom: L("Smart Zoom")
        case .dragSpaces: L("Spaces & Mission Control")
        case .dragScroll: L("Scroll & Navigate")
        default: title
        }
    }
    var title: String { L(en) }
    private var en: String {
        switch self {
        case .none: "Do nothing"
        case .click: "Default click"
        case .missionControl: "Mission Control"
        case .appExpose: "App Exposé"
        case .launchpad: "Launchpad"
        case .showDesktop: "Show Desktop"
        case .spaceLeft: "Space to the left"
        case .spaceRight: "Space to the right"
        case .back: "Back"
        case .forward: "Forward"
        case .lookUp: "Look up"
        case .screenshot: "Screenshot area"
        case .zoomIn: "Zoom in"
        case .zoomOut: "Zoom out"
        case .smartZoom: "Smart zoom"
        case .secondaryClick: "Secondary click"
        case .primaryClick: "Primary click"
        case .middleClick: "Middle click"
        case .appSwitcher: "Switch to previous app"
        case .swipeSpaceLeft: "Space to the left (swipe animation)"
        case .swipeSpaceRight: "Space to the right (swipe animation)"
        case .swipeMissionControl: "Mission Control (swipe, experimental)"
        case .swipeAppExpose: "App Exposé (swipe, experimental)"
        case .swipeDesktop: "Show Desktop (pinch, experimental)"
        case .swipeLaunchpad: "Launchpad (pinch, experimental)"
        case .dragSpaces: "Spaces & Mission Control (live drag)"
        case .swipeBack: "Back (three-finger swipe, experimental)"
        case .swipeForward: "Forward (three-finger swipe, experimental)"
        case .dragScroll: "Scroll & navigate (drag)"
        case .playPause: "Play / Pause"
        case .nextTrack: "Next track"
        case .prevTrack: "Previous track"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        case .mute: "Mute"
        case .brightnessUp: "Brightness up"
        case .brightnessDown: "Brightness down"
        case .shortcut: "Keyboard shortcut…"
        }
    }
}

enum ModKey: String, Codable, CaseIterable, Identifiable {
    case none, shift, option, control, command
    var id: String { rawValue }
    var title: String { L(en) }
    private var en: String {
        switch self {
        case .none: "Off"
        case .shift: "⇧ Shift"
        case .option: "⌥ Option"
        case .control: "⌃ Control"
        case .command: "⌘ Command"
        }
    }
    var flag: CGEventFlags? {
        switch self {
        case .none: nil
        case .shift: .maskShift
        case .option: .maskAlternate
        case .control: .maskControl
        case .command: .maskCommand
        }
    }
}

enum ScrollFx: String, Codable, CaseIterable, Identifiable {
    case none, horizontal, quick, precise, zoom, rotate, spaces, desktopLaunchpad, appSwitcher
    var id: String { rawValue }
    /// Names the original app uses (Buttons tab).
    var simple: String {
        switch self {
        case .horizontal: L("Horizontal Scroll")
        case .quick: L("Swift Scroll")
        case .precise: L("Precise Scroll")
        case .zoom: L("Zoom In or Out")
        case .rotate: L("Rotate")
        case .spaces: L("Move Between Spaces")
        case .desktopLaunchpad: L("Desktop & Launchpad")
        case .appSwitcher: L("App Switcher")
        case .none: title
        }
    }
    var title: String { L(en) }
    private var en: String {
        switch self {
        case .none: "Normal scroll"
        case .horizontal: "Horizontal scroll"
        case .quick: "Quick scroll"
        case .precise: "Precise scroll"
        case .zoom: "Zoom in or out"
        case .rotate: "Rotate"
        case .spaces: "Move between Spaces"
        case .desktopLaunchpad: "Desktop & Launchpad"
        case .appSwitcher: "App Switcher"
        }
    }
}

/// An action plus, for `.shortcut`, the text of the shortcut (e.g. "cmd+shift+4").
struct Do: Codable {
    var act: Act = .none
    var key = ""
    init(_ a: Act = .none) { act = a }
}

struct Btn: Codable {
    var n: Int // CGEvent button number: 2 = middle, 3 = "button 4", ...
    var click = Do(), dbl = Do(), tri = Do(), hold = Do(), hold2 = Do(), hold3 = Do()
    var withHeld: [String: Do] = [:] // action when this button is clicked while another one (key = its number) is held
    var up = Do(), down = Do(), left = Do(), right = Do()
    var scroll = ScrollFx.none // what the wheel does while this button is held
    var name: String { n == 2 ? L("Middle button") : String(format: L("Button %d"), n + 1) }
    /// Nothing to intercept: let the real click through untouched.
    var isIdle: Bool {
        click.act == .click && scroll == .none && [dbl, tri, hold, hold2, hold3, up, down, left, right].allSatisfy { $0.act == .none }
            && withHeld.values.allSatisfy { $0.act == .none }
    }
}

extension Btn {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        n = try c.decode(Int.self, forKey: .n)
        click = try c.decodeIfPresent(Do.self, forKey: .click) ?? Do()
        dbl = try c.decodeIfPresent(Do.self, forKey: .dbl) ?? Do()
        tri = try c.decodeIfPresent(Do.self, forKey: .tri) ?? Do()
        hold = try c.decodeIfPresent(Do.self, forKey: .hold) ?? Do()
        hold2 = try c.decodeIfPresent(Do.self, forKey: .hold2) ?? Do()
        hold3 = try c.decodeIfPresent(Do.self, forKey: .hold3) ?? Do()
        withHeld = try c.decodeIfPresent([String: Do].self, forKey: .withHeld) ?? [:]
        up = try c.decodeIfPresent(Do.self, forKey: .up) ?? Do()
        down = try c.decodeIfPresent(Do.self, forKey: .down) ?? Do()
        left = try c.decodeIfPresent(Do.self, forKey: .left) ?? Do()
        right = try c.decodeIfPresent(Do.self, forKey: .right) ?? Do()
        scroll = try c.decodeIfPresent(ScrollFx.self, forKey: .scroll) ?? .none
    }
}

struct Profile: Codable {
    var smooth = true
    var reverse = false
    var speed = 0.75        // multiplier on pixels per wheel notch
    var smoothness = 0.12  // easing time constant, seconds
    var accel = true       // faster notches in a row scroll further
    var modifiers = true   // use the keyboard modifiers below while scrolling
    var kHorizontal = ModKey.shift
    var kQuick = ModKey.control   // "Swift Scroll" in the original
    var kPrecise = ModKey.option
    var kZoom = ModKey.command
    var kRotate = ModKey.none
    var swipeOneSpace = false // Spaces & Mission Control drag: false = follows the whole drag, true = at most one Space per drag
    var momentum = true    // send trackpad-style scroll/momentum phases so apps glide naturally
    var buttons: [Btn] = Profile.defaultButtons(five: Profile.mouseHasFiveButtons)

    /// Number of buttons the connected mouse reports (HID button usages), cached.
    static let mouseHasFiveButtons: Bool = {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(mgr, [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 2] as CFDictionary)
        guard let devs = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> else { return true }
        var best = 0
        for d in devs {
            let els = (IOHIDDeviceCopyMatchingElements(d, [kIOHIDElementUsagePageKey: 9] as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement]) ?? []
            best = max(best, els.map { Int(IOHIDElementGetUsage($0)) }.max() ?? 0)
        }
        return best >= 5 || best == 0
    }()

    /// The original app's defaults. 3 buttons: middle button does everything. 5+: button 4 = desktop management, button 5 = zoom/scroll.
    static func defaultButtons(five: Bool) -> [Btn] {
        func dragAll(_ b: inout Btn, _ a: Act) { b.up = Do(a); b.down = Do(a); b.left = Do(a); b.right = Do(a) }
        if !five {
            var mid = Btn(n: 2)
            mid.click = Do(.missionControl); mid.hold = Do(.showDesktop); mid.dbl = Do(.launchpad)
            dragAll(&mid, .dragSpaces)
            return [mid]
        }
        var b4 = Btn(n: 3), b5 = Btn(n: 4)
        b4.click = Do(.missionControl); b4.scroll = .desktopLaunchpad; dragAll(&b4, .dragSpaces)
        b5.click = Do(.smartZoom); b5.scroll = .zoom; dragAll(&b5, .dragScroll)
        return [b4, b5]
    }
}

extension Profile {
    /// A button we can pass straight through: no action of its own, and not a chord partner.
    func idle(_ b: Btn) -> Bool {
        b.isIdle && !buttons.contains { ($0.withHeld[String(b.n)]?.act ?? .none) != .none }
    }
    // tolerant decoding so settings saved by older builds survive new fields
    init(from d: Decoder) throws {
        self.init()
        let c = try d.container(keyedBy: CodingKeys.self)
        smooth = try c.decodeIfPresent(Bool.self, forKey: .smooth) ?? smooth
        reverse = try c.decodeIfPresent(Bool.self, forKey: .reverse) ?? reverse
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? speed
        smoothness = try c.decodeIfPresent(Double.self, forKey: .smoothness) ?? smoothness
        accel = try c.decodeIfPresent(Bool.self, forKey: .accel) ?? accel
        modifiers = try c.decodeIfPresent(Bool.self, forKey: .modifiers) ?? modifiers
        momentum = try c.decodeIfPresent(Bool.self, forKey: .momentum) ?? momentum
        swipeOneSpace = try c.decodeIfPresent(Bool.self, forKey: .swipeOneSpace) ?? swipeOneSpace
        kHorizontal = try c.decodeIfPresent(ModKey.self, forKey: .kHorizontal) ?? kHorizontal
        kQuick = try c.decodeIfPresent(ModKey.self, forKey: .kQuick) ?? kQuick
        kPrecise = try c.decodeIfPresent(ModKey.self, forKey: .kPrecise) ?? kPrecise
        kZoom = try c.decodeIfPresent(ModKey.self, forKey: .kZoom) ?? kZoom
        kRotate = try c.decodeIfPresent(ModKey.self, forKey: .kRotate) ?? kRotate
        buttons = try c.decodeIfPresent([Btn].self, forKey: .buttons) ?? buttons
    }
}

struct AppEntry: Codable, Identifiable {
    var id: String // bundle identifier
    var name: String
    var profile: Profile
}

struct Config: Codable {
    var profile = Profile()
    var apps: [AppEntry] = []
    var scrollEnabled = true   // kill switches, like the original
    var buttonsEnabled = true
    var showMenuBar = true
    var lockPointer = true     // freeze the cursor while a button gesture is held
    var pointerEnabled = false // manage the mouse pointer speed (off = leave the system setting alone)
    var pointerSpeed = 1.5     // system tracking speed, 0...3 (same scale as System Settings)
    var pointerAccel = true    // off = flat response, no acceleration curve
    var updateURL = ""         // update source: GitHub releases API URL, or JSON with "version" and "url"
    var autoUpdate = false
    var appByPointer = false   // pick per-app settings by the app under the pointer instead of the frontmost one
}

extension Config {
    init(from d: Decoder) throws {
        self.init()
        let c = try d.container(keyedBy: CodingKeys.self)
        profile = try c.decodeIfPresent(Profile.self, forKey: .profile) ?? profile
        apps = try c.decodeIfPresent([AppEntry].self, forKey: .apps) ?? apps
        scrollEnabled = try c.decodeIfPresent(Bool.self, forKey: .scrollEnabled) ?? true
        buttonsEnabled = try c.decodeIfPresent(Bool.self, forKey: .buttonsEnabled) ?? true
        showMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showMenuBar) ?? true
        lockPointer = try c.decodeIfPresent(Bool.self, forKey: .lockPointer) ?? true
        pointerEnabled = try c.decodeIfPresent(Bool.self, forKey: .pointerEnabled) ?? false
        pointerSpeed = try c.decodeIfPresent(Double.self, forKey: .pointerSpeed) ?? 1.5
        pointerAccel = try c.decodeIfPresent(Bool.self, forKey: .pointerAccel) ?? true
        appByPointer = try c.decodeIfPresent(Bool.self, forKey: .appByPointer) ?? false
        updateURL = try c.decodeIfPresent(String.self, forKey: .updateURL) ?? ""
        autoUpdate = try c.decodeIfPresent(Bool.self, forKey: .autoUpdate) ?? false
    }
}

final class Store: ObservableObject {
    static let shared = Store()
    private static let key = "config.v2"
    @Published var updateStatus = ""   // result of the last update check (not saved)
    @Published var updateLink: URL?
    @Published var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "enabled"); Snap.update(cfg, enabled: enabled) }
    }
    @Published var cfg: Config {
        didSet {
            if let d = try? JSONEncoder().encode(cfg) { UserDefaults.standard.set(d, forKey: Store.key) }
            Snap.update(cfg, enabled: enabled)
        }
    }
    init() {
        if let d = UserDefaults.standard.data(forKey: Store.key), let c = try? JSONDecoder().decode(Config.self, from: d) { cfg = c }
        else { cfg = Config() }
        Snap.update(cfg, enabled: enabled)
    }
    /// Per-app profile if the frontmost app has one, otherwise the default.
    func profile(for bundle: String?) -> Profile {
        cfg.apps.first { $0.id == bundle }?.profile ?? cfg.profile
    }
}

// MARK: - Settings snapshot for the event thread

/// The UI edits `Store` on the main thread; the event thread reads this locked copy instead.
enum Snap {
    private static let lock = NSLock()
    private static var _cfg = Config(), _enabled = true, _front: String?
    static var cfg: Config { lock.lock(); defer { lock.unlock() }; return _cfg }
    static var enabled: Bool { lock.lock(); defer { lock.unlock() }; return _enabled }
    static var front: String? {
        get { lock.lock(); defer { lock.unlock() }; return _front }
        set { lock.lock(); _front = newValue; lock.unlock() }
    }
    static func update(_ c: Config, enabled: Bool) {
        lock.lock(); _cfg = c; _enabled = enabled; lock.unlock()
    }
    static func profile(for bundle: String?) -> Profile {
        let c = cfg
        return c.apps.first { $0.id == bundle }?.profile ?? c.profile
    }
}

// MARK: - Helper (LaunchAgent)

/// Optional launchd agent: starts the app at login and restarts it if it dies. The same binary runs with --background.
enum Helper {
    static let label = "local.mousefixer.helper"
    static var plist: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist") }
    static var installed: Bool { FileManager.default.fileExists(atPath: plist.path) }
    static var domain: String { "gui/\(getuid())" }

    @discardableResult static func launchctl(_ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        try? p.run(); p.waitUntilExit()
        return p.terminationStatus
    }

    /// Hands over to a launchd-managed copy and exits this process.
    static func install() {
        let d: [String: Any] = ["Label": label, "ProgramArguments": [Bundle.main.executablePath ?? "", "--background"],
                                "RunAtLoad": true, "KeepAlive": true, "AbandonProcessGroup": true, "ProcessType": "Interactive"]
        try? FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: d, format: .xml, options: 0),
              (try? data.write(to: plist)) != nil else { return }
        Pointer.skipRestore = true // the new copy owns the pointer setting now
        launchctl(["bootstrap", domain, plist.path])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exit(0) }
    }

    /// Stops the agent, removes it and starts a plain copy again (the detached relaunch survives the bootout).
    static func uninstall() {
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; /usr/bin/open -g '\(Bundle.main.bundlePath)' --args --background"]
        try? relaunch.run()
        try? FileManager.default.removeItem(at: plist)
        launchctl(["bootout", "\(domain)/\(label)"])
    }

    /// Quit for good this session (launchd would otherwise restart us).
    static func stop() { launchctl(["bootout", "\(domain)/\(label)"]) }
}

// MARK: - Updates

enum Updater {
    static var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    /// Numeric dotted-version compare: "1.10" > "1.9".
    static func newer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    /// Fetches the source and reports (latest version, link) or nil on any failure.
    /// Accepts a GitHub release ({tag_name, html_url}) or {version, url}. https only (plain http for localhost).
    static func fetch(_ s: String, done: @escaping ((version: String, link: URL?)?) -> Void) {
        guard let u = URL(string: s.trimmingCharacters(in: .whitespaces)),
              u.scheme == "https" || (u.scheme == "http" && ["localhost", "127.0.0.1"].contains(u.host ?? "")) else { return done(nil) }
        var r = URLRequest(url: u, timeoutInterval: 15)
        r.setValue("MouseFixer/\(current)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: r) { data, _, _ in
            guard let data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let v = (j["tag_name"] ?? j["version"]) as? String else { return done(nil) }
            let link = ((j["html_url"] ?? j["url"]) as? String).flatMap(URL.init(string:))
            done((v.hasPrefix("v") ? String(v.dropFirst()) : v, link))
        }.resume()
    }
}

extension Store {
    func checkForUpdates(silent: Bool = false) {
        guard !cfg.updateURL.isEmpty else { self.updateStatus = L("No update source set"); return }
        Updater.fetch(cfg.updateURL) { [self] res in
            DispatchQueue.main.async {
                guard let res else { self.updateStatus = L("Could not check for updates"); self.updateLink = nil; return }
                self.updateLink = res.link
                if Updater.newer(res.version, than: Updater.current) {
                    self.updateStatus = String(format: L("Update available: %@"), res.version)
                    if silent, let l = res.link { NSWorkspace.shared.open(l) }
                } else {
                    self.updateStatus = String(format: L("Up to date (version %@)"), Updater.current)
                    self.updateLink = nil
                }
            }
        }
    }
}

// MARK: - Pointer

/// Mouse pointer speed / acceleration through the HID system parameter (affects mice, not trackpads).
/// The original value is remembered and put back when the feature is turned off or the app quits.
enum Pointer {
    static let handle = NXOpenEventStatus()
    static let key = kIOHIDMouseAccelerationType as CFString
    static var skipRestore = false
    /// The user's own value, kept on disk while overridden so a crash or a handover to the helper cannot lose it.
    static var saved: Double? {
        get { UserDefaults.standard.object(forKey: "pointerOriginal") as? Double }
        set { UserDefaults.standard.set(newValue, forKey: "pointerOriginal") }
    }

    static func apply(_ c: Config) {
        guard c.pointerEnabled else { return restore() }
        if saved == nil {
            var v = 0.0
            if IOHIDGetAccelerationWithKey(handle, key, &v) == 0 { saved = v }
        }
        _ = IOHIDSetAccelerationWithKey(handle, key, c.pointerAccel ? c.pointerSpeed : -1)
        // macOS can put the system speed back (e.g. a Bluetooth mouse reconnecting), so re-apply every 2 s while on
        if keeper == nil {
            keeper = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                let c = Store.shared.cfg
                if c.pointerEnabled { _ = IOHIDSetAccelerationWithKey(handle, key, c.pointerAccel ? c.pointerSpeed : -1) }
            }
        }
    }
    static var keeper: Timer?

    static func restore() {
        guard !skipRestore, let o = saved else { return }
        _ = IOHIDSetAccelerationWithKey(handle, key, o)
        UserDefaults.standard.removeObject(forKey: "pointerOriginal")
    }
}

// MARK: - Actions

let marker: Int64 = 0x4D46_5845 // tags events we post so the tap ignores them

/// Press or release a modifier key on its own (Command stays held while the app switcher is open).
func modKey(_ code: CGKeyCode, down: Bool) {
    let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
    e?.flags = down ? .maskCommand : []
    e?.setIntegerValueField(.eventSourceUserData, value: marker)
    e?.post(tap: .cghidEventTap)
}

func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
    if ProcessInfo.processInfo.environment["MF_DOCK_LOG"] != nil { print("key \(code)"); return } // debug: log instead of pressing
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
        e?.flags = flags
        e?.setIntegerValueField(.eventSourceUserData, value: marker)
        e?.post(tap: .cghidEventTap)
    }
}

// ANSI virtual key codes for the shortcut text field
let keyCodes: [String: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13,
    "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25,
    "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36,
    "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
    "tab": 48, "space": 49, "`": 50, "delete": 51, "esc": 53, "left": 123, "right": 124, "down": 125, "up": 126,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101,
    "f10": 109, "f11": 103, "f12": 111,
]

let fnKeys: Set<CGKeyCode> = [123, 124, 125, 126, 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

/// "cmd+shift+4" -> keystroke. Unknown text does nothing.
func shortcut(_ text: String) {
    var flags: CGEventFlags = []
    var code: CGKeyCode?
    for tok in text.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
        switch tok {
        case "cmd", "command": flags.insert(.maskCommand)
        case "shift": flags.insert(.maskShift)
        case "opt", "option", "alt": flags.insert(.maskAlternate)
        case "ctrl", "control": flags.insert(.maskControl)
        case "fn": flags.insert(.maskSecondaryFn)
        default: code = keyCodes[tok]
        }
    }
    guard let c = code else { return }
    if fnKeys.contains(c) { flags.insert(.maskSecondaryFn) } // arrows and F-keys carry the fn flag
    key(c, flags)
}

/// Two-finger double-tap on a trackpad = HID "zoom toggle" gesture (type 29, subtype 22).
/// Private event layout, unverified on real apps.
func smartZoom() {
    guard let e = CGEvent(source: nil), let f = CGEventField(rawValue: 110), let t = CGEventType(rawValue: 29) else { return }
    e.type = t
    e.setIntegerValueField(f, value: 22)
    e.post(tap: .cghidEventTap)
}

/// Three-finger dock swipe (Spaces / Mission Control) as a synthetic gesture: begin, 10 steps, end with velocity.
/// Horizontal (motion 1) was seen switching Spaces; vertical (motion 2) is a guess.
let dockQueue = DispatchQueue(label: "dock-gesture") // posted off the event-tap thread, in order

var lastDockChange = 0.0
func dockPost(_ phase: Int64, _ motion: Int64, _ offset: Double, _ vel: Double) {
    if phase == 2 { // at most ~120 changes a second; the end event carries the final offset anyway
        let t = CACurrentMediaTime()
        if t - lastDockChange < 0.008 { return }
        lastDockChange = t
    }
    dockQueue.async {
        dockPostNow(phase, motion, offset, vel)
        if phase == 1 { usleep(20000) } // the Dock drops a change that follows a begin too closely
    }
}

func dockPostNow(_ phase: Int64, _ motion: Int64, _ offset: Double, _ vel: Double) {
    if ProcessInfo.processInfo.environment["MF_DOCK_LOG"] != nil { print("dock phase=\(phase) motion=\(motion) offset=\(String(format: "%.2f", offset)) vel=\(vel)"); return } // debug: log instead of gesturing
    guard let g = CGEvent(source: nil), let d = CGEvent(source: nil),
          let t29 = CGEventType(rawValue: 29), let t30 = CGEventType(rawValue: 30) else { return }
    func f(_ n: UInt32) -> CGEventField { CGEventField(rawValue: n)! }
    g.type = t29
    g.setIntegerValueField(f(110), value: 23)
    g.setIntegerValueField(f(132), value: phase)
    g.post(tap: .cghidEventTap)
    d.type = t30
    d.setIntegerValueField(f(110), value: 23)
    d.setIntegerValueField(f(132), value: phase)
    d.setIntegerValueField(f(134), value: phase)
    d.setIntegerValueField(f(123), value: motion)
    d.setDoubleValueField(f(124), value: offset)
    d.setDoubleValueField(f(129), value: vel)
    d.setDoubleValueField(f(130), value: vel)
    d.post(tap: .cghidEventTap)
}

/// Navigation swipe (Safari/Chrome back/forward): HID event type 16 with a direction flag
/// (IOHID swipe mask: up 1, down 2, left 4, right 8). Layout is from memory and untested.
func navSwipe(forward: Bool) {
    dockQueue.async {
        func f(_ n: UInt32) -> CGEventField { CGEventField(rawValue: n)! }
        for phase: Int64 in [1, 4] {
            guard let e = CGEvent(source: nil), let t = CGEventType(rawValue: 29) else { return }
            e.type = t
            e.setIntegerValueField(f(110), value: 16)
            e.setIntegerValueField(f(132), value: phase)
            e.setIntegerValueField(f(117), value: forward ? 4 : 8) // swipe left = forward, right = back
            e.post(tap: .cghidEventTap)
            usleep(30000)
        }
    }
}

func dockSwipe(motion: Int64, dir: Double) {
    DispatchQueue.global().async {
        dockPostNow(1, motion, 0, 0); usleep(20000)
        var o = 0.0
        for _ in 0..<10 { o += 0.1 * dir; dockPostNow(2, motion, o, 0); usleep(16000) }
        dockPostNow(4, motion, o, dir * 2)
    }
}

/// Apple-keyboard keys (volume, brightness, media) are "system defined" events, not key codes.
func mediaKey(_ k: Int) {
    for down in [true, false] {
        let flags = down ? 0xa00 : 0xb00
        NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                           timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: (k << 16) | flags, data2: -1)?
            .cgEvent?.post(tap: .cghidEventTap)
    }
}

func openApp(_ paths: [String]) {
    if let p = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: p), configuration: .init())
    }
}

func middleClick(_ button: Int) {
    let loc = CGEvent(source: nil)?.location ?? .zero
    for t in [CGEventType.otherMouseDown, .otherMouseUp] {
        guard let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: loc,
                              mouseButton: CGMouseButton(rawValue: UInt32(button)) ?? .center) else { continue }
        e.setIntegerValueField(.mouseEventClickState, value: 1)
        e.setIntegerValueField(.eventSourceUserData, value: marker)
        e.post(tap: .cgSessionEventTap)
    }
}

func perform(_ d: Do, button: Int) {
    let ctrlFn: CGEventFlags = [.maskControl, .maskSecondaryFn]
    switch d.act {
    case .none: break
    case .click: middleClick(button)
    case .missionControl: key(126, ctrlFn)
    case .appExpose: key(125, ctrlFn)
    case .spaceLeft: key(123, ctrlFn)
    case .spaceRight: key(124, ctrlFn)
    case .showDesktop: key(103, .maskSecondaryFn)
    case .launchpad: openApp(["/System/Applications/Apps.app", "/System/Applications/Launchpad.app"])
    case .back: key(33, .maskCommand)
    case .forward: key(30, .maskCommand)
    case .lookUp: key(2, [.maskCommand, .maskControl])
    case .screenshot: key(21, [.maskCommand, .maskShift])
    case .zoomIn: key(24, .maskCommand)
    case .zoomOut: key(27, .maskCommand)
    case .smartZoom: smartZoom()
    case .primaryClick, .middleClick, .secondaryClick:
        let loc = CGEvent(source: nil)?.location ?? .zero
        let (down, up, btn): (CGEventType, CGEventType, CGMouseButton) = d.act == .primaryClick ? (.leftMouseDown, .leftMouseUp, .left)
            : d.act == .middleClick ? (.otherMouseDown, .otherMouseUp, .center) : (.rightMouseDown, .rightMouseUp, .right)
        for t in [down, up] {
            let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: loc, mouseButton: btn)
            e?.setIntegerValueField(.eventSourceUserData, value: marker)
            e?.post(tap: .cgSessionEventTap)
        }
    case .appSwitcher: key(48, .maskCommand)
    case .dragScroll: break // handled in the drag path
    case .swipeSpaceLeft: dockSwipe(motion: 1, dir: -1)
    case .swipeSpaceRight: dockSwipe(motion: 1, dir: 1)
    case .swipeMissionControl: dockSwipe(motion: 2, dir: 1)
    case .swipeAppExpose: dockSwipe(motion: 2, dir: -1)
    case .swipeDesktop: dockSwipe(motion: 3, dir: 1)
    case .swipeLaunchpad: dockSwipe(motion: 3, dir: -1)
    case .dragSpaces: break // handled in the drag path
    case .swipeBack: navSwipe(forward: false)
    case .swipeForward: navSwipe(forward: true)
    case .playPause: mediaKey(16)
    case .nextTrack: mediaKey(17)
    case .prevTrack: mediaKey(18)
    case .volumeUp: mediaKey(0)
    case .volumeDown: mediaKey(1)
    case .mute: mediaKey(7)
    case .brightnessUp: mediaKey(2)
    case .brightnessDown: mediaKey(3)
    case .shortcut: shortcut(d.key)
    }
}

// MARK: - Event engine

/// Synthetic trackpad pinch (kind 8) or rotation (kind 5). Private event layout, unverified on real apps.
final class GestureStream {
    let kind: Int64
    var active = false
    var timer: Timer?
    init(kind: Int64) { self.kind = kind }
    func add(_ amount: Double) {
        if !active { post(1, 0); active = true }
        post(2, amount)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [self] _ in post(4, 0); active = false }
    }
    private func post(_ phase: Int64, _ value: Double) {
        guard let e = CGEvent(source: nil), let t = CGEventType(rawValue: 29),
              let fKind = CGEventField(rawValue: 110), let fPhase = CGEventField(rawValue: 132),
              let fVal = CGEventField(rawValue: kind == 8 ? 113 : 114) else { return }
        e.type = t
        e.setIntegerValueField(fKind, value: kind)
        e.setIntegerValueField(fPhase, value: phase)
        e.setDoubleValueField(fVal, value: value)
        e.post(tap: .cgSessionEventTap)
    }
}

/// Live dock gesture driven by the wheel (e.g. 4-finger pinch for Desktop & Launchpad). Layout unverified for motion 3.
final class DockStream {
    let motion: Int64
    var active = false, off = 0.0
    var timer: Timer?
    init(motion: Int64) { self.motion = motion }
    func add(_ d: Double) {
        if !active {
            active = true; off = 0
            dockQueue.async { dockPostNow(1, self.motion, 0, 0); usleep(20000) } // the Dock drops a begin and change sent back to back
        }
        off += d
        dockPost(2, motion, off, 0)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [self] _ in
            dockPost(4, motion, off, abs(off) > 0.1 ? (off > 0 ? 2 : -2) : 0)
            active = false
        }
    }
}

/// What the "Add" sheet recorded from the mouse.
struct Trigger {
    enum Kind { case click, hold, drag, scroll }
    var n: Int            // CGEvent button number
    var kind: Kind
    var level: Int        // 1 = single, 2 = double, 3 = triple
}

final class Engine {
    static let shared = Engine()
    var tap: CFMachPort?

    // smooth scrolling state
    var rem = [0.0, 0.0]      // remaining pixels [vertical, horizontal]
    var carry = [0.0, 0.0]    // sub-pixel remainder
    var flags: CGEventFlags = []
    var timer: Timer?
    var last = CACurrentMediaTime()
    var lastNotch = 0.0
    var streak = 1.0

    // button gesture state
    struct Gesture { var dx = 0.0, dy = 0.0, fired = false, scrolling = false, hold: Timer?, start = CACurrentMediaTime(), last = 0.0, chord: Int?, motion: Int64 = 0, off = 0.0, axis = 0, vFired = false, dir = 0.0 }
    var lastProfile = Profile()
    var gestures: [Int: Gesture] = [:]
    var pending: [Int: (taps: Int, timer: Timer)] = [:]  // clicks waiting to see if more follow
    let zoom = GestureStream(kind: 8), rotate = GestureStream(kind: 5)
    var spaceAcc = 0.0
    let pinch = DockStream(motion: 3)
    var switcherOn = false, switcherAcc = 0.0
    var switcherTimer: Timer?

    // trigger capture for the Add sheet
    var capture: ((Trigger) -> Void)?
    var capN = -1, capTaps = 0, capDrag = 0.0, capIsDown = false
    var capTimer: Timer?, capHold: Timer?
    var zoomAcc = 0.0
    var stage = 0 // scroll phase: 0 idle, 1 fingers-down, 3 ended (momentum next), 2 momentum
    var front: String? { Snap.front }  // bundle id of the frontmost app, for per-app profiles
    var pointerLookup: (t: Double, bundle: String?) = (0, nil)
    let dragThreshold = 60.0

    /// App whose settings apply to this event: frontmost app, or the one whose window is under the pointer.
    func bundle(for ev: CGEvent) -> String? {
        guard Snap.cfg.appByPointer else { return front }
        let now = CACurrentMediaTime()
        if now - pointerLookup.t < 0.1 { return pointerLookup.bundle ?? front } // the window list is slow: reuse it for 100 ms
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return front }
        let p = ev.location
        for w in list where (w[kCGWindowLayer as String] as? Int) == 0 {
            guard let d = w[kCGWindowBounds as String] as? NSDictionary, let r = CGRect(dictionaryRepresentation: d),
                  r.contains(p), let pid = w[kCGWindowOwnerPID as String] as? pid_t else { continue }
            let b = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
            pointerLookup = (now, b)
            return b ?? front
        }
        pointerLookup = (now, nil)
        return front
    }

    func watchFrontApp() {
        Snap.front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { n in
            Snap.front = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
        }
    }

    var runLoop: CFRunLoop?

    /// Runs `block` on the event thread (everything the engine owns lives there).
    func onEngine(_ block: @escaping () -> Void) {
        guard let rl = runLoop else { return block() }
        CFRunLoopPerformBlock(rl, CFRunLoopMode.commonModes.rawValue, block)
        CFRunLoopWakeUp(rl)
    }

    func setCapture(_ cb: ((Trigger) -> Void)?) {
        onEngine { [self] in
            capture = cb
            capTimer?.invalidate(); capHold?.invalidate()
            capTaps = 0; capIsDown = false; capN = -1
        }
    }

    /// The tap, its timers and all gesture state run on their own thread so a busy UI can never stall input.
    func start() -> Bool {
        if tap != nil { return true }
        _ = Store.shared // loads the saved settings into Snap before the first event
        var ok = false
        let ready = DispatchSemaphore(value: 0)
        let t = Thread { [self] in
            let types: [CGEventType] = [.scrollWheel, .otherMouseDown, .otherMouseUp, .otherMouseDragged]
            let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
            guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                               eventsOfInterest: mask, callback: { _, type, ev, _ in
                Engine.shared.handle(type, ev)
            }, userInfo: nil) else { ready.signal(); return }
            tap = port
            runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(runLoop, CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            ok = true
            // safety net: if a release was ever missed, never leave the pointer frozen or a Dock swipe hanging
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [self] _ in
                for (n, g) in gestures where CACurrentMediaTime() - max(g.start, g.last) > 2 // quiet for 2 s and the OS says the button is up
                    && !CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: UInt32(n)) ?? .center) {
                    resetGestures(); break
                }
            }
            ready.signal()
            CFRunLoopRun()
        }
        t.name = "mousefixer.engine"
        t.qualityOfService = .userInteractive
        t.start()
        ready.wait()
        return ok
    }

    /// Drop any half-finished gesture: unfreeze the pointer, end a running Dock swipe, forget pending taps.
    func resetGestures() {
        for g in gestures.values { g.hold?.invalidate(); if g.motion != 0 { dockPost(4, g.motion, g.off, 0) } }
        gestures.removeAll()
        for p in pending.values { p.timer.invalidate() }
        pending.removeAll()
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    func handle(_ type: CGEventType, _ ev: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(ev)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            resetGestures() // the release of a held button may have been lost
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return pass
        }
        let cfg = Snap.cfg
        if ev.getIntegerValueField(.eventSourceUserData) == marker || !Snap.enabled {
            if !Snap.enabled && !gestures.isEmpty { resetGestures() }
            return pass
        }
        if let cap = capture, captureEvent(type, ev, cap) { return nil }
        // drags and releases belong to the press that started them: keep its profile
        let c = type == .otherMouseDragged || type == .otherMouseUp ? lastProfile : Snap.profile(for: bundle(for: ev))
        lastProfile = c
        switch type {
        case .scrollWheel:
            // trackpads and our own output are continuous; only touch real wheels
            if !cfg.scrollEnabled || ev.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return pass }
            var v = ev.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            var h = ev.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            var f = ev.flags
            let fx = effect(&f, c)
            switch fx {
            case .zoom: zoom.add(v * 0.04); return nil
            case .rotate: rotate.add(v * 3); return nil
            case .desktopLaunchpad: pinch.add(-v * 0.12); return nil
            case .appSwitcher:
                switcherAcc += v
                while abs(switcherAcc) >= 1 {
                    if !switcherOn { switcherOn = true; modKey(55, down: true) }
                    key(48, switcherAcc < 0 ? .maskCommand : [.maskCommand, .maskShift]) // wheel down = next app
                    switcherAcc -= switcherAcc > 0 ? 1 : -1
                }
                switcherTimer?.invalidate()
                switcherTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [self] _ in modKey(55, down: false); switcherOn = false }
                return nil
            case .spaces:
                spaceAcc += v
                while abs(spaceAcc) >= 1 {
                    perform(Do(spaceAcc > 0 ? .spaceLeft : .spaceRight), button: 0)
                    spaceAcc -= spaceAcc > 0 ? 1 : -1
                }
                return nil
            default: break
            }
            if !c.smooth {
                if c.reverse {
                    for (d, p, q) in [(CGEventField.scrollWheelEventDeltaAxis1, CGEventField.scrollWheelEventPointDeltaAxis1, CGEventField.scrollWheelEventFixedPtDeltaAxis1),
                                      (.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2)] {
                        ev.setIntegerValueField(d, value: -ev.getIntegerValueField(d))
                        ev.setIntegerValueField(p, value: -ev.getIntegerValueField(p))
                        ev.setDoubleValueField(q, value: -ev.getDoubleValueField(q))
                    }
                }
                return pass
            }
            if c.reverse { v = -v; h = -h }
            var factor = c.speed * 50
            switch fx {
            case .horizontal: swap(&v, &h)
            case .quick: factor *= 4
            case .precise: factor *= 0.25
            default: break
            }
            let now = CACurrentMediaTime()
            // fast spins ramp up to 5x, closer to the native wheel acceleration (the old 2x cap felt sluggish)
            streak = (c.accel && now - lastNotch < 0.12) ? min(streak + 0.4, 5) : 1
            lastNotch = now
            flags = f
            if stage == 2 { emit(0, 0, sp: 0, mp: 3) } // new input cancels running momentum
            if stage >= 2 { stage = 0 }
            rem[0] += v * factor * streak
            rem[1] += h * factor * streak
            if timer == nil {
                last = now
                timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.tick() }
                RunLoop.current.add(timer!, forMode: .common)
            }
            return nil

        case .otherMouseDown:
            let n = Int(ev.getIntegerValueField(.mouseEventButtonNumber))
            guard cfg.buttonsEnabled, let b = c.buttons.first(where: { $0.n == n }) else { return pass }
            // chord: another swallowed button is held and this one has an action for it
            if let a = gestures.keys.first(where: { $0 != n && (b.withHeld[String($0)]?.act ?? .none) != .none }) {
                gestures[a]?.fired = true // the held button is now a modifier, not a click
                var g = Gesture()
                g.chord = a
                gestures[n] = g
                return nil
            }
            guard !c.idle(b) else { return pass }
            var g = Gesture()
            // a press right after earlier taps is a double/triple "hold" candidate
            pending[n]?.timer.invalidate()
            let level = (pending[n]?.taps ?? 0) + 1
            let holdAct = level == 1 ? b.hold : level == 2 ? b.hold2 : b.hold3
            if holdAct.act != .none {
                g.hold = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                    guard var g = self?.gestures[n], !g.fired else { return }
                    g.fired = true
                    self?.gestures[n] = g
                    self?.pending[n] = nil
                    perform(holdAct, button: n)
                }
            }
            gestures[n] = g
            if cfg.lockPointer { CGAssociateMouseAndMouseCursorPosition(0) } // freeze cursor while held
            return nil

        case .otherMouseDragged:
            let n = Int(ev.getIntegerValueField(.mouseEventButtonNumber))
            guard var g = gestures[n] else { return pass }
            let dx = ev.getDoubleValueField(.mouseEventDeltaX), dy = ev.getDoubleValueField(.mouseEventDeltaY)
            g.dx += dx
            g.dy += dy
            g.last = CACurrentMediaTime()
            if let b = c.buttons.first(where: { $0.n == n }) {
                if [b.up, b.down, b.left, b.right].contains(where: { $0.act == .dragScroll }) {
                    // drag the page like a touchscreen. A few pixels of hand jitter must not eat a click.
                    flags = []
                    if g.scrolling { emit(Int(dy.rounded()), Int(dx.rounded()), sp: 2, mp: 0) }
                    else if max(abs(g.dx), abs(g.dy)) >= 12 {
                        g.hold?.invalidate(); g.fired = true; g.scrolling = true
                        pending.removeValue(forKey: n)?.timer.invalidate()
                        emit(Int(g.dy.rounded()), Int(g.dx.rounded()), sp: 1, mp: 0) // includes the movement before the threshold
                    }
                } else if [b.up, b.down, b.left, b.right].contains(where: { $0.act == .dragSpaces }) {
                    // up/down shows Mission Control / Application Windows exactly like the click does;
                    // left/right is a live three-finger Space swipe that follows the mouse both ways
                    if g.axis == 0 {
                        if max(abs(g.dx), abs(g.dy)) >= 16 { // below this it is still a click
                            g.hold?.invalidate(); g.fired = true
                            pending.removeValue(forKey: n)?.timer.invalidate()
                            g.axis = abs(g.dx) > abs(g.dy) ? 1 : 2
                            if g.axis == 1 { g.motion = 1; g.dir = 0; g.off = -g.dx / (c.swipeOneSpace ? 600 : 300); if c.swipeOneSpace { g.off = max(-1, min(1, g.off)) }; dockPost(1, 1, 0, 0); dockPost(2, 1, g.off, 0) } // includes the movement before the threshold // begin on its own event: the Dock drops a begin and a change sent back to back
                        }
                    } else if g.axis == 2 {
                        if !g.vFired, abs(g.dy) >= 30 {
                            g.vFired = true
                            perform(Do(g.dy < 0 ? .missionControl : .appExpose), button: n)
                        }
                    } else {
                        let step = -dx / (c.swipeOneSpace ? 600 : 300) // one-at-a-time needs twice the distance: slower
                        g.off += step
                        if c.swipeOneSpace { g.off = max(-1, min(1, g.off)) } // 1.0 = exactly the neighboring Space; reversing moves back at once
                        g.dir = 0.6 * g.dir + 0.4 * step
                        dockPost(2, 1, g.off, 0)
                    }
                } else if !g.fired, max(abs(g.dx), abs(g.dy)) >= dragThreshold {
                    g.fired = true
                    g.hold?.invalidate()
                    pending.removeValue(forKey: n)?.timer.invalidate()
                    let a: Do = abs(g.dx) > abs(g.dy) ? (g.dx < 0 ? b.left : b.right) : (g.dy < 0 ? b.up : b.down)
                    perform(a, button: n)
                }
            }
            gestures[n] = g
            return nil

        case .otherMouseUp:
            let n = Int(ev.getIntegerValueField(.mouseEventButtonNumber))
            guard let g = gestures.removeValue(forKey: n) else { return pass }
            if gestures.isEmpty { CGAssociateMouseAndMouseCursorPosition(1) }
            g.hold?.invalidate()
            if let a = g.chord {
                if let d = c.buttons.first(where: { $0.n == n })?.withHeld[String(a)] { perform(d, button: n) }
                return nil
            }
            if g.motion != 0 { // commit toward where the mouse was heading when released
                // settle on a whole Space in the direction the mouse was last heading (reversed late = back to where it started),
                // gliding there so the Dock never has to guess from a velocity
                let heading = abs(g.dir) > 0.002 ? g.dir : g.off
                var target = 0.0
                if abs(g.off) >= 0.15 { target = heading > 0 ? max(0, ceil(g.off - 1e-6)) : min(0, floor(g.off + 1e-6)) }
                let from = g.off, m = g.motion
                dockQueue.async {
                    let n = 8
                    for i in 1...n { dockPostNow(2, m, from + (target - from) * Double(i) / Double(n), 0); usleep(12000) }
                    dockPostNow(4, m, target, target == 0 ? 0 : (target > 0 ? 2 : -2))
                }
                return nil
            }
            if g.scrolling { flags = []; emit(0, 0, sp: 4, mp: 0); return nil }
            guard !g.fired, let b = c.buttons.first(where: { $0.n == n }) else { return nil }
            // count taps; fire once no further tap can follow
            let maxLevel = b.tri.act != .none || b.hold3.act != .none ? 3 : b.dbl.act != .none || b.hold2.act != .none ? 2 : 1
            var taps = 1
            if let p = pending.removeValue(forKey: n) { p.timer.invalidate(); if CACurrentMediaTime() - g.start < 0.4 { taps = p.taps + 1 } }
            let act = taps >= 3 ? b.tri : taps == 2 ? b.dbl : b.click
            if taps >= maxLevel { perform(act, button: n) }
            else {
                let t = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                    self?.pending[n] = nil
                    perform(act, button: n)
                }
                pending[n] = (taps, t)
            }
            return nil

        default: return pass
        }
    }

    /// Records one trigger (click / double / triple, hold, drag, scroll) for the Add sheet. True = swallow the event.
    func captureEvent(_ type: CGEventType, _ ev: CGEvent, _ cb: @escaping (Trigger) -> Void) -> Bool {
        func finish(_ t: Trigger) {
            capTimer?.invalidate(); capHold?.invalidate()
            capture = nil; capTaps = 0; capIsDown = false; capN = -1
            DispatchQueue.main.async { cb(t) }
        }
        let n = Int(ev.getIntegerValueField(.mouseEventButtonNumber))
        switch type {
        case .otherMouseDown:
            capTimer?.invalidate()
            if capN != n { capTaps = 0 }
            capN = n; capIsDown = true; capDrag = 0
            capHold = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [self] _ in
                if capIsDown { finish(Trigger(n: n, kind: .hold, level: min(capTaps + 1, 3))) }
            }
            return true
        case .otherMouseDragged:
            capDrag += abs(ev.getDoubleValueField(.mouseEventDeltaX)) + abs(ev.getDoubleValueField(.mouseEventDeltaY))
            if capIsDown, capDrag >= 25 { finish(Trigger(n: capN, kind: .drag, level: min(capTaps + 1, 3))) }
            return true
        case .otherMouseUp:
            guard capIsDown else { return true }
            capIsDown = false; capHold?.invalidate(); capTaps += 1
            if capTaps >= 3 { finish(Trigger(n: n, kind: .click, level: 3)) }
            else { capTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [self] _ in finish(Trigger(n: n, kind: .click, level: capTaps)) } }
            return true
        case .scrollWheel:
            guard capIsDown, ev.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else { return false }
            finish(Trigger(n: capN, kind: .scroll, level: min(capTaps + 1, 3)))
            return true
        default: return false
        }
    }

    /// Which scroll effect applies: a held mouse button wins, then keyboard modifiers. Strips the modifier it used.
    func effect(_ f: inout CGEventFlags, _ c: Profile) -> ScrollFx {
        for n in Array(gestures.keys) {
            if let b = c.buttons.first(where: { $0.n == n }), b.scroll != .none {
                gestures[n]?.fired = true // wheel used: releasing the button is not a click
                gestures[n]?.last = CACurrentMediaTime() // wheel use counts as activity for the stuck-button safety net
                return b.scroll
            }
        }
        guard c.modifiers else { return .none }
        for (k, fx) in [(c.kZoom, ScrollFx.zoom), (c.kRotate, .rotate), (c.kHorizontal, .horizontal), (c.kQuick, .quick), (c.kPrecise, .precise)] {
            if let fl = k.flag, f.contains(fl) { f.remove(fl); return fx }
        }
        return .none
    }

    func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - last, 0.05)
        last = now
        let k = 1 - exp(-dt / max(lastProfile.smoothness, 0.01))
        var out = [0, 0]
        for i in 0..<2 {
            var step = rem[i] * k
            if abs(rem[i]) < 0.5 { step = rem[i] }
            rem[i] -= step
            carry[i] += step
            out[i] = Int(carry[i].rounded())
            carry[i] -= Double(out[i])
        }
        var sp = 0, mp = 0
        if lastProfile.momentum {
            if now - lastNotch < 0.1 { sp = stage == 0 ? 1 : 2; stage = 1 }
            else {
                if stage == 1 { emit(0, 0, sp: 4, mp: 0); stage = 3 }
                mp = stage == 2 ? 2 : 1
                stage = 2
            }
        }
        if out[0] != 0 || out[1] != 0 { emit(out[0], out[1], sp: sp, mp: mp) }
        if rem[0] == 0 && rem[1] == 0 {
            if stage == 2 { emit(0, 0, sp: 0, mp: 3) } else if stage == 1 { emit(0, 0, sp: 4, mp: 0) }
            stage = 0
            timer?.invalidate(); timer = nil; carry = [0, 0]
        }
    }

    /// Post one continuous pixel scroll event, optionally tagged with trackpad scroll / momentum phases.
    func emit(_ y: Int, _ x: Int, sp: Int, mp: Int) {
        guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                              wheel1: Int32(y), wheel2: Int32(x), wheel3: 0) else { return }
        e.flags = flags
        e.location = CGEvent(source: nil)?.location ?? .zero
        e.setIntegerValueField(.eventSourceUserData, value: marker)
        if sp != 0 { e.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(sp)) }
        if mp != 0 { e.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(mp)) }
        e.post(tap: .cgSessionEventTap)
    }
}

// MARK: - UI

struct DoRow: View {
    let title: LocalizedStringKey
    @Binding var d: Do
    var body: some View {
        HStack {
            Picker(title, selection: $d.act) { ForEach(Act.allCases) { Text($0.title).tag($0) } }
            if d.act == .shortcut { TextField("cmd+shift+4", text: $d.key).frame(width: 120) }
        }
    }
}

struct ModRow: View {
    let title: LocalizedStringKey
    @Binding var k: ModKey
    var body: some View { Picker(title, selection: $k) { ForEach(ModKey.allCases) { Text($0.title).tag($0) } } }
}

struct AdvancedView: View {
    @ObservedObject var s = Store.shared
    @State var sel = "" // "" = all apps, else bundle id
    @State var trusted = AXIsProcessTrusted()
    @State var login = SMAppService.mainApp.status == .enabled
    @State var helperOn = Helper.installed
    let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var prof: Binding<Profile> {
        Binding(get: { s.cfg.apps.first { $0.id == sel }?.profile ?? s.cfg.profile },
                set: { p in
                    if let i = s.cfg.apps.firstIndex(where: { $0.id == sel }) { s.cfg.apps[i].profile = p }
                    else { s.cfg.profile = p }
                })
    }

    func addApp() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.application]
        p.directoryURL = URL(fileURLWithPath: "/Applications")
        guard p.runModal() == .OK, let u = p.url, let id = Bundle(url: u)?.bundleIdentifier else { return }
        if !s.cfg.apps.contains(where: { $0.id == id }) {
            s.cfg.apps.append(AppEntry(id: id, name: FileManager.default.displayName(atPath: u.path), profile: s.cfg.profile))
        }
        sel = id
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("Settings for", selection: $sel) {
                    Text("All apps").tag("")
                    ForEach(s.cfg.apps) { Text($0.name).tag($0.id) }
                }
                Button("Add app…", action: addApp)
                if !sel.isEmpty {
                    Button("Remove") { s.cfg.apps.removeAll { $0.id == sel }; sel = "" }
                }
            }.padding([.horizontal, .top])
            if !sel.isEmpty {
                Text("Applies only while this app is frontmost. Overrides the “All apps” settings completely.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            TabView {
                Form {
                    Toggle("Smooth scrolling", isOn: prof.smooth)
                    Toggle("Reverse mouse scroll direction", isOn: prof.reverse)
                    Toggle("Momentum (trackpad-style glide)", isOn: prof.momentum).disabled(!prof.wrappedValue.smooth)
                    Toggle("Scroll faster on quick successive notches", isOn: prof.accel).disabled(!prof.wrappedValue.smooth)
                    Section("Keyboard modifiers while scrolling") {
                        Toggle("Enable modifiers", isOn: prof.modifiers)
                        ModRow(title: "Horizontal scroll", k: prof.kHorizontal)
                        ModRow(title: "Quick scroll", k: prof.kQuick)
                        ModRow(title: "Precise scroll", k: prof.kPrecise)
                        ModRow(title: "Zoom in or out", k: prof.kZoom)
                        ModRow(title: "Rotate", k: prof.kRotate)
                    }.disabled(false)
                    Slider(value: prof.speed, in: 0.3...3) { Text("Speed") }.disabled(!prof.wrappedValue.smooth)
                    Slider(value: prof.smoothness, in: 0.03...0.4) { Text("Smoothness") }.disabled(!prof.wrappedValue.smooth)
                    Text("Only affects mouse wheels. Trackpads are untouched.").font(.caption).foregroundStyle(.secondary)
                }.tabItem { Text("Scrolling") }.padding()

                Form {
                    ForEach(prof.buttons, id: \.n) { $b in
                        DisclosureGroup(b.name) {
                            DoRow(title: "Click", d: $b.click)
                            DoRow(title: "Double click", d: $b.dbl)
                            DoRow(title: "Triple click", d: $b.tri)
                            DoRow(title: "Hold", d: $b.hold)
                            DoRow(title: "Double click and hold", d: $b.hold2)
                            DoRow(title: "Triple click and hold", d: $b.hold3)
                            DoRow(title: "Drag up", d: $b.up)
                            DoRow(title: "Drag down", d: $b.down)
                            DoRow(title: "Drag left", d: $b.left)
                            DoRow(title: "Drag right", d: $b.right)
                            Picker("Scroll wheel while held", selection: $b.scroll) {
                                ForEach(ScrollFx.allCases) { Text($0.title).tag($0) }
                            }
                            ForEach(prof.wrappedValue.buttons.filter { $0.n != b.n }, id: \.n) { other in
                                DoRow(title: "Click while holding \(other.name)", d: Binding(
                                    get: { b.withHeld[String(other.n)] ?? Do() },
                                    set: { b.withHeld[String(other.n)] = $0 }))
                            }
                        }
                    }
                    Section {
                        Menu("Add button…") {
                            ForEach(2...8, id: \.self) { n in
                                if !prof.wrappedValue.buttons.contains(where: { $0.n == n }) {
                                    Button(Btn(n: n).name) {
                                        var p = prof.wrappedValue
                                        var b = Btn(n: n); b.click = Do(.click)
                                        p.buttons.append(b); p.buttons.sort { $0.n < $1.n }
                                        prof.wrappedValue = p
                                    }
                                }
                            }
                        }
                    }
                }.formStyle(.grouped).tabItem { Text("Buttons") }

                Form {
                    Toggle("Launch at login", isOn: Binding(get: { login }, set: { on in
                        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
                        login = SMAppService.mainApp.status == .enabled
                    }))
                    Toggle("Capture scrolling", isOn: $s.cfg.scrollEnabled)
                    Toggle("Capture mouse buttons", isOn: $s.cfg.buttonsEnabled)
                    Toggle("Show menu bar icon (relaunch the app to reopen settings if hidden)", isOn: $s.cfg.showMenuBar)
                    Toggle("Freeze pointer during button gestures", isOn: $s.cfg.lockPointer)
                    Toggle("Pick per-app settings by the app under the pointer", isOn: $s.cfg.appByPointer)
                    Toggle("Run as background helper (starts at login, restarts if it quits)", isOn: Binding(get: { helperOn }, set: { on in
                        helperOn = on
                        if on { Helper.install() } else { Helper.uninstall() }
                    }))
                    Section("Updates") {
                        TextField("Update source URL", text: $s.cfg.updateURL)
                        Toggle("Check for updates automatically", isOn: $s.cfg.autoUpdate)
                        HStack {
                            Button("Check now") { s.checkForUpdates() }
                            Text(s.updateStatus).font(.caption).foregroundStyle(.secondary)
                            if let l = s.updateLink { Button("Download") { NSWorkspace.shared.open(l) } }
                        }
                    }
                    Section("Pointer (mouse only)") {
                        Toggle("Override system pointer settings", isOn: $s.cfg.pointerEnabled)
                        Toggle("Pointer acceleration", isOn: $s.cfg.pointerAccel).disabled(!s.cfg.pointerEnabled)
                        Slider(value: $s.cfg.pointerSpeed, in: 0...3) { Text("Speed \(s.cfg.pointerSpeed, specifier: "%.2f")") }
                            .disabled(!s.cfg.pointerEnabled || !s.cfg.pointerAccel)
                        Text("Speed uses the same scale as System Settings. With acceleration off the pointer moves at a flat rate.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    LabeledContent("Accessibility access", value: L(trusted ? "Granted" : "Missing"))
                    Button("Reset all settings (including per-app)") { s.cfg = Config(); sel = "" }
                }.tabItem { Text("General") }.padding()
            }
        }
        .onReceive(poll) { _ in trusted = AXIsProcessTrusted() }
    }
}

// MARK: - Simple UI (the original app's layout)

/// One row of the Buttons table = one slot of one button.
enum Slot: Hashable { case click, dbl, tri, hold, hold2, hold3, drag, scroll }

let clickEffects: [Act] = [.primaryClick, .secondaryClick, .middleClick, .back, .forward, .missionControl, .appExpose, .showDesktop,
                           .launchpad, .spaceLeft, .spaceRight, .lookUp, .smartZoom, .shortcut,
                           .brightnessUp, .brightnessDown, .volumeUp, .volumeDown, .mute, .playPause, .prevTrack, .nextTrack]
let dragEffects: [Act] = [.dragSpaces, .dragScroll]
let scrollEffects: [ScrollFx] = [.horizontal, .quick, .precise, .zoom, .rotate, .desktopLaunchpad, .spaces, .appSwitcher]

extension Btn {
    func value(_ s: Slot) -> Do {
        switch s {
        case .click: return click
        case .dbl: return dbl
        case .tri: return tri
        case .hold: return hold
        case .hold2: return hold2
        case .hold3: return hold3
        case .drag: return [up, down, left, right].first { $0.act != .none } ?? Do()
        case .scroll: return Do()
        }
    }
    mutating func set(_ s: Slot, _ d: Do) {
        switch s {
        case .click: click = d
        case .dbl: dbl = d
        case .tri: tri = d
        case .hold: hold = d
        case .hold2: hold2 = d
        case .hold3: hold3 = d
        case .drag: up = d; down = d; left = d; right = d
        case .scroll: break
        }
    }
    /// Slots that have a rule. A plain default click is not a rule.
    var activeSlots: [Slot] {
        var r: [Slot] = []
        if click.act != .none && click.act != .click { r.append(.click) }
        if dbl.act != .none { r.append(.dbl) }
        if tri.act != .none { r.append(.tri) }
        if hold.act != .none { r.append(.hold) }
        if hold2.act != .none { r.append(.hold2) }
        if hold3.act != .none { r.append(.hold3) }
        if value(.drag).act != .none { r.append(.drag) }
        if scroll != .none { r.append(.scroll) }
        return r
    }
}

func triggerText(_ b: Btn, _ s: Slot) -> String {
    let name = b.name
    let f: String
    switch s {
    case .click: f = "Click %@"
    case .dbl: f = "Double Click %@"
    case .tri: f = "Triple Click %@"
    case .hold: f = "Hold %@"
    case .hold2: f = "Double Click and Hold %@"
    case .hold3: f = "Triple Click and Hold %@"
    case .drag: f = "Click and Drag %@"
    case .scroll: f = "Click and Scroll %@"
    }
    return String(format: L(f), name)
}

func slot(for t: Trigger) -> Slot {
    switch t.kind {
    case .click: return [Slot.click, .dbl, .tri][t.level - 1]
    case .hold: return [Slot.hold, .hold2, .hold3][t.level - 1]
    case .drag: return .drag
    case .scroll: return .scroll
    }
}

struct EffectPicker: View {
    let slot: Slot
    @Binding var b: Btn
    var body: some View {
        HStack {
            if slot == .scroll {
                Picker("", selection: $b.scroll) {
                    ForEach(scrollEffects + (scrollEffects.contains(b.scroll) ? [] : [b.scroll])) { Text($0.simple).tag($0) }
                }.labelsHidden().frame(width: 190)
            } else {
                let cur = b.value(slot)
                let list = (slot == .drag ? dragEffects : clickEffects)
                Picker("", selection: Binding(get: { b.value(slot).act }, set: { a in var d = b.value(slot); d.act = a; b.set(slot, d) })) {
                    ForEach(list + (list.contains(cur.act) ? [] : [cur.act])) { Text($0.simple).tag($0) }
                }.labelsHidden().frame(width: cur.act == .shortcut ? 130 : 190)
                if cur.act == .shortcut {
                    TextField("cmd+shift+4", text: Binding(get: { b.value(slot).key }, set: { k in var d = b.value(slot); d.key = k; b.set(slot, d) }))
                        .frame(width: 90)
                }
            }
        }
    }
}

struct AddRuleSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var s = Store.shared
    @State var trigger: Trigger?
    @State var draft = Btn(n: 0)

    var body: some View {
        VStack(spacing: 14) {
            if let t = trigger {
                let b = Btn(n: t.n)
                Text(triggerText(b, slot(for: t))).font(.headline)
                EffectPicker(slot: slot(for: t), b: $draft)
                HStack {
                    Button("Cancel") { dismiss() }
                    Button("Add") { add(t); dismiss() }.keyboardShortcut(.defaultAction)
                }
            } else {
                Image(systemName: "computermouse").font(.system(size: 34)).foregroundStyle(.secondary)
                Text("Click, double click, hold or drag a mouse button, or scroll the wheel while holding it.")
                    .multilineTextAlignment(.center)
                Text("The primary and secondary buttons can't be used.").font(.caption).foregroundStyle(.secondary)
                Button("Cancel") { dismiss() }
            }
        }
        .padding(24).frame(width: 380)
        .onAppear {
            Engine.shared.setCapture { t in
                draft = Btn(n: t.n)
                switch t.kind {
                case .drag: draft.set(.drag, Do(.dragSpaces))
                case .scroll: draft.scroll = .zoom
                default: draft.set(slot(for: t), Do(.missionControl))
                }
                trigger = t
            }
        }
        .onDisappear { Engine.shared.setCapture(nil) }
    }

    func add(_ t: Trigger) {
        var p = s.cfg.profile
        var b = p.buttons.first { $0.n == t.n } ?? { var x = Btn(n: t.n); x.click = Do(.click); return x }()
        let sl = slot(for: t)
        if sl == .scroll { b.scroll = draft.scroll } else { b.set(sl, draft.value(sl)) }
        p.buttons.removeAll { $0.n == t.n }
        p.buttons.append(b)
        p.buttons.sort { $0.n < $1.n }
        s.cfg.profile = p
    }
}

struct SimpleButtons: View {
    @ObservedObject var s = Store.shared
    @State var adding = false
    @State var restoring = false

    struct RowRef: Identifiable { let i: Int; let slot: Slot; let n: Int; var id: String { "\(n)-\(slot)" } }
    var rows: [RowRef] {
        s.cfg.profile.buttons.enumerated().flatMap { i, b in b.activeSlots.map { RowRef(i: i, slot: $0, n: b.n) } }
    }

    func remove(_ i: Int, _ sl: Slot) {
        var b = s.cfg.profile.buttons[i]
        switch sl {
        case .scroll: b.scroll = .none
        case .click: b.click = Do(.click) // back to the button's normal click
        default: b.set(sl, Do())
        }
        s.cfg.profile.buttons[i] = b
    }

    var body: some View {
        VStack(spacing: 8) {
            List {
                ForEach(rows) { r in
                    HStack {
                        Text(triggerText(s.cfg.profile.buttons[r.i], r.slot)).frame(maxWidth: .infinity, alignment: .leading)
                        EffectPicker(slot: r.slot, b: $s.cfg.profile.buttons[r.i])
                        Button { remove(r.i, r.slot) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                    }
                }
                if rows.isEmpty { Text("No button actions. Click + to add one.").foregroundStyle(.secondary) }
            }
            if s.cfg.profile.buttons.contains(where: { $0.value(.drag).act == .dragSpaces }) {
                Picker("Spaces & Mission Control drag", selection: $s.cfg.profile.swipeOneSpace) {
                    Text("Move through all Spaces").tag(false)
                    Text("Move one Space at a time").tag(true)
                }.padding(.horizontal, 12)
            }
            HStack {
                Button { adding = true } label: { Image(systemName: "plus") }
                Spacer()
                Button("Restore Defaults…") { restoring = true }
            }.padding([.horizontal, .bottom], 12)
        }
        .sheet(isPresented: $adding) { AddRuleSheet() }
        .confirmationDialog("Restore Default for ...", isPresented: $restoring) {
            Button("Mouse with 3 buttons") { s.cfg.profile.buttons = Profile.defaultButtons(five: false) }
            Button("Mouse with 5+ buttons") { s.cfg.profile.buttons = Profile.defaultButtons(five: true) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct SimpleScroll: View {
    @ObservedObject var s = Store.shared
    enum Level: String, CaseIterable, Identifiable { case off = "Off", regular = "Regular", high = "High"; var id: String { rawValue } }
    enum Speed: String, CaseIterable, Identifiable { case low = "Low", medium = "Medium", high = "High"; var id: String { rawValue } }

    var smooth: Binding<Level> {
        Binding(get: { !s.cfg.profile.smooth ? .off : s.cfg.profile.smoothness < 0.1 ? .regular : .high },
                set: { l in
                    s.cfg.profile.smooth = l != .off
                    if l != .off { s.cfg.profile.smoothness = l == .regular ? 0.07 : 0.12 }
                })
    }
    var speed: Binding<Speed> {
        Binding(get: { s.cfg.profile.speed < 0.5 ? .low : s.cfg.profile.speed > 1.0 ? .high : .medium },
                set: { s.cfg.profile.speed = $0 == .low ? 0.3 : $0 == .medium ? 0.75 : 1.3 })
    }

    var body: some View {
        Form {
            Picker("Smooth Scrolling", selection: smooth) { ForEach(Level.allCases) { Text(L($0.rawValue)).tag($0) } }
            Picker("Scrolling Speed", selection: speed) { ForEach(Speed.allCases) { Text(L($0.rawValue)).tag($0) } }
            Toggle("Reverse Direction", isOn: $s.cfg.profile.reverse)
            Toggle("Trackpad Simulation", isOn: $s.cfg.profile.momentum)
            Section("Modifier Keys") {
                Toggle("Enable modifier keys", isOn: $s.cfg.profile.modifiers)
                ModRow(title: "Horizontal Scroll", k: $s.cfg.profile.kHorizontal)
                ModRow(title: "Zoom In or Out", k: $s.cfg.profile.kZoom)
                ModRow(title: "Swift Scroll", k: $s.cfg.profile.kQuick)
                ModRow(title: "Precise Scroll", k: $s.cfg.profile.kPrecise)
            }
        }.formStyle(.grouped)
    }
}

struct SimpleGeneral: View {
    @ObservedObject var s = Store.shared
    @State var login = SMAppService.mainApp.status == .enabled
    @State var trusted = AXIsProcessTrusted()
    let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(get: { login }, set: { on in
                do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
                login = SMAppService.mainApp.status == .enabled
            }))
            Toggle("Show menu bar icon (relaunch the app to reopen settings if hidden)", isOn: $s.cfg.showMenuBar)
            LabeledContent("Accessibility access", value: L(trusted ? "Granted" : "Missing"))
            Text("Need more control? See the More options tab.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped).onReceive(poll) { _ in trusted = AXIsProcessTrusted() }
    }
}

struct SettingsView: View {
    @ObservedObject var s = Store.shared
    @AppStorage("tab") var tab = 0 // remembered between launches
    @State var trusted = AXIsProcessTrusted()
    let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 44, height: 44)
                VStack(alignment: .leading) {
                    Text("Mouse Fixer").font(.title2.bold())
                    Text(L(!trusted ? "Needs Accessibility access" : s.enabled ? "Active" : "Paused"))
                        .font(.caption).foregroundStyle(!trusted ? .orange : s.enabled ? .green : .secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: $s.enabled).toggleStyle(.switch).labelsHidden()
            }.padding([.horizontal, .top])
            if !trusted {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Allow Mouse Fixer in Privacy & Security → Accessibility, then restart it.").font(.callout)
                    Spacer()
                    Button("Open") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }.padding(10).background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal)
            }
            TabView(selection: $tab) {
                SimpleButtons().tabItem { Text("Buttons") }.tag(0)
                SimpleScroll().tabItem { Text("Scrolling") }.tag(1)
                SimpleGeneral().tabItem { Text("General") }.tag(2)
                AdvancedView().tabItem { Text("More options") }.tag(3)
            }
        }
        .frame(width: 560, height: 680)
        .onReceive(poll) { _ in trusted = AXIsProcessTrusted() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var item: NSStatusItem!
    var window: NSWindow?
    var retry: Timer?
    var vis: AnyCancellable?
    var sigs: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Mouse Fixer")
        let m = NSMenu()
        m.delegate = self
        let en = m.addItem(withTitle: L("Enabled"), action: #selector(toggleEnabled), keyEquivalent: "")
        en.target = self
        m.addItem(withTitle: L("Settings…"), action: #selector(showSettings), keyEquivalent: ",").target = self
        m.addItem(.separator())
        m.addItem(withTitle: L("Quit Mouse Fixer"), action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = m
        item.isVisible = Store.shared.cfg.showMenuBar
        vis = Store.shared.$cfg.sink { [weak self] c in
            self?.item.isVisible = c.showMenuBar
            Pointer.apply(c)
        }
        Pointer.apply(Store.shared.cfg)
        for sig in [SIGTERM, SIGINT] { // put the system pointer setting back on kill
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { Pointer.restore(); exit(0) }
            src.resume()
            sigs.append(src)
        }

        Engine.shared.watchFrontApp()
        // at most one automatic check per day
        let last = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        if Store.shared.cfg.autoUpdate, Date().timeIntervalSince1970 - last > 86400 {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")
            Store.shared.checkForUpdates(silent: true)
        }
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        let ok = Engine.shared.start()
        FileHandle.standardError.write("trusted=\(AXIsProcessTrusted()) tap=\(ok)\n".data(using: .utf8)!)
        if !ok {
            // permission not granted yet: keep trying until it is
            retry = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
                if Engine.shared.start() { t.invalidate(); self?.retry = nil }
            }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--screenshot"), i + 1 < CommandLine.arguments.count {
            // debug: render the settings window offscreen to a PNG without showing it
            showSettings(); window?.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let v = self.window?.contentView, let r = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                    v.cacheDisplay(in: v.bounds, to: r)
                    try? r.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
                }
                exit(0)
            }
        } else if !CommandLine.arguments.contains("--background") { showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }

    @objc func quit() { if Helper.installed { Helper.stop() } else { NSApp.terminate(nil) } }

    @objc func toggleEnabled() { Store.shared.enabled.toggle() }
    func menuNeedsUpdate(_ menu: NSMenu) { menu.items.first?.state = Store.shared.enabled ? .on : .off }

    @objc func showSettings() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Mouse Fixer"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ n: Notification) { CGAssociateMouseAndMouseCursorPosition(1); Pointer.restore() }
}

if let i = CommandLine.arguments.firstIndex(of: "--check-updates"), i + 1 < CommandLine.arguments.count { // debug
    let sem = DispatchSemaphore(value: 0)
    Updater.fetch(CommandLine.arguments[i + 1]) { r in
        print(r.map { "latest=\($0.version) newer=\(Updater.newer($0.version, than: Updater.current)) link=\($0.link?.absoluteString ?? "-")" } ?? "failed")
        sem.signal()
    }
    sem.wait(); exit(0)
}
if CommandLine.arguments.contains("--helper-install") { Helper.install(); RunLoop.main.run() } // debug
if CommandLine.arguments.contains("--helper-uninstall") { Helper.uninstall(); exit(0) } // debug
if CommandLine.arguments.contains("--print-config") { // debug
    let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
    print(String(data: try! e.encode(Store.shared.cfg.profile.buttons), encoding: .utf8)!); exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--l10n-key"), i + 1 < CommandLine.arguments.count { print(L(CommandLine.arguments[i + 1])); exit(0) } // debug
if CommandLine.arguments.contains("--selftest-drag") { // debug: drag 600px with button 6 and log the dock gesture offsets (MF_DOCK_LOG=1)
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    guard Engine.shared.start() else { print("no accessibility"); exit(1) }
    func post(_ t: CGEventType, dx: Int64 = 0, dy: Int64 = 0) {
        let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: CGMouseButton(rawValue: 5)!)!
        e.setIntegerValueField(.mouseEventDeltaX, value: dx); e.setIntegerValueField(.mouseEventDeltaY, value: dy); e.post(tap: .cghidEventTap)
    }
    DispatchQueue.global().async {
        let scenario = CommandLine.arguments.last ?? ""
        usleep(500000); post(.otherMouseDown); usleep(60000)
        func drag(_ n: Int, dx: Int64 = 0, dy: Int64 = 0) { for _ in 0..<n { post(.otherMouseDragged, dx: dx, dy: dy); usleep(25000) } }
        switch scenario {
        case "reverse": drag(20, dx: -30); drag(10, dx: 30)   // out 600px left, then change mind and come back 300px
        case "up": drag(5, dy: -30)
        case "down": drag(5, dy: 30)
        default: drag(20, dx: -30)
        }
        post(.otherMouseUp); usleep(600000); exit(0)
    }
    app.run()
}
if CommandLine.arguments.contains("--selftest-capture") { // debug: record synthetic button input through the Add-sheet capture
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    guard Engine.shared.start() else { print("no accessibility"); exit(1) }
    func post(_ t: CGEventType, _ b: Int, dy: Int64 = 0) {
        let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: CGMouseButton(rawValue: UInt32(b))!)!
        e.setIntegerValueField(.mouseEventDeltaY, value: dy); e.post(tap: .cghidEventTap)
    }
    func arm(_ name: String) { Engine.shared.setCapture { t in print("\(name): button \(t.n) \(t.kind) level \(t.level)") } }
    DispatchQueue.global().async {
        usleep(500000)
        arm("single click"); post(.otherMouseDown, 5); usleep(40000); post(.otherMouseUp, 5); usleep(700000)
        arm("double click"); for _ in 0..<2 { post(.otherMouseDown, 5); usleep(40000); post(.otherMouseUp, 5); usleep(80000) }; usleep(700000)
        arm("triple click"); for _ in 0..<3 { post(.otherMouseDown, 5); usleep(40000); post(.otherMouseUp, 5); usleep(80000) }; usleep(700000)
        arm("hold"); post(.otherMouseDown, 5); usleep(700000); post(.otherMouseUp, 5); usleep(300000)
        arm("tap then hold"); post(.otherMouseDown, 5); usleep(40000); post(.otherMouseUp, 5); usleep(100000); post(.otherMouseDown, 5); usleep(700000); post(.otherMouseUp, 5); usleep(300000)
        arm("drag"); post(.otherMouseDown, 5); usleep(40000); for _ in 0..<3 { post(.otherMouseDragged, 5, dy: 15); usleep(20000) }; post(.otherMouseUp, 5); usleep(300000)
        arm("scroll while held"); post(.otherMouseDown, 5); usleep(60000)
        CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0)!.post(tap: .cghidEventTap); usleep(300000); post(.otherMouseUp, 5); usleep(300000)
        exit(0)
    }
    app.run()
}
if CommandLine.arguments.contains("--print-l10n") { print(L("Settings…"), "|", L("Smooth scrolling")); exit(0) } // debug

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
