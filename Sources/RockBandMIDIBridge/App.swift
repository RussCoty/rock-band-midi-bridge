import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    let bridge = Bridge()
    var window: NSWindow!
    var statusItem: NSStatusItem!
    var statusLabel: NSTextField!
    var activityLabel: NSTextField!
    var output: NSPopUpButton!
    var channel: NSPopUpButton!
    var octave: NSPopUpButton!
    var touch: NSPopUpButton!
    var timer: Timer?
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
        withExtendedLifetime(delegate) {}
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x:0,y:0,width:580,height:490), styleMask:[.titled,.closable,.miniaturizable], backing:.buffered, defer:false)
        window.title = "Rock Band Wireless MIDI Bridge"; window.center(); window.isReleasedWhenClosed = false
        let view = NSView(frame:NSRect(x:0,y:0,width:580,height:490)); window.contentView = view
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        func label(_ text: String, _ y: CGFloat, _ bold: Bool = false) -> NSTextField {
            let field = NSTextField(labelWithString:text); field.frame = NSRect(x:28,y:y,width:524,height:24)
            field.font = bold ? .boldSystemFont(ofSize:22) : .systemFont(ofSize:13)
            view.addSubview(field); return field
        }
        _ = label("Rock Band MIDI Bridge", 437, true)
        let subtitle = label("Wii wireless keyboard → your favourite synth", 409)
        subtitle.textColor = .secondaryLabelColor
        statusLabel = label("Starting…", 365)
        statusLabel.font = .systemFont(ofSize:13, weight:.medium)
        _ = label("MIDI output", 318)
        output = NSPopUpButton(frame:NSRect(x:168,y:315,width:383,height:28))
        output.target = self; output.action = #selector(AppDelegate.changeOutput); view.addSubview(output)
        let refresh = NSButton(title:"Refresh outputs", target:self, action:#selector(AppDelegate.reloadOutputs))
        refresh.frame = NSRect(x:409,y:282,width:143,height:27); view.addSubview(refresh)
        _ = label("MIDI channel", 244); channel = NSPopUpButton(frame:NSRect(x:228,y:241,width:323,height:28)); channel.addItems(withTitles:(1...16).map(String.init))
        _ = label("Lowest key", 204); octave = NSPopUpButton(frame:NSRect(x:228,y:201,width:323,height:28)); octave.addItems(withTitles:(1...8).map { "C\($0 - 1) — MIDI \($0 * 12)" }); octave.selectItem(at:3)
        _ = label("Touch strip", 164); touch = NSPopUpButton(frame:NSRect(x:228,y:161,width:323,height:28)); touch.addItems(withTitles:["Modulation — CC1", "Filter cutoff — CC74", "Expression — CC11"])
        for control in [channel!,octave!,touch!] { view.addSubview(control); control.target = self; control.action = #selector(AppDelegate.changeSettings) }
        let panicButton = NSButton(title:"Release all notes",target:self,action:#selector(AppDelegate.panic)); panicButton.frame = NSRect(x:25,y:108,width:170,height:32); view.addSubview(panicButton)
        let help = NSButton(title:"Setup guide",target:self,action:#selector(AppDelegate.help)); help.frame = NSRect(x:425,y:108,width:128,height:32); view.addSubview(help)
        activityLabel = label("", 69); activityLabel.font = .monospacedDigitSystemFont(ofSize:12,weight:.regular)
        let footer = label("Wii receiver only · USB 1BAD:3330 · v1.2.0", 24)
        footer.textColor = .secondaryLabelColor; footer.font = .systemFont(ofSize:11)
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength); statusItem.button?.title = "RB MIDI"
        let menu = NSMenu(); menu.addItem(withTitle:"Show Bridge",action:#selector(AppDelegate.show),keyEquivalent:""); menu.addItem(withTitle:"Panic",action:#selector(AppDelegate.panic),keyEquivalent:""); menu.addItem(.separator());menu.addItem(withTitle:"Quit",action:#selector(AppDelegate.quit),keyEquivalent:"q")
        for item in menu.items { item.target = self }; statusItem.menu = menu
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Rock Band MIDI Bridge")
        appMenu.addItem(withTitle: "Show Bridge", action: #selector(AppDelegate.show), keyEquivalent: "")
        appMenu.addItem(withTitle: "Panic / release notes", action: #selector(AppDelegate.panic), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Rock Band MIDI Bridge", action: #selector(AppDelegate.quit), keyEquivalent: "q")
        for item in appMenu.items { item.target = self }
        appMenuItem.submenu = appMenu; mainMenu.addItem(appMenuItem); NSApp.mainMenu = mainMenu
        var startupError: String?
        do { try bridge.start(); refreshOutputs() } catch { startupError = error.localizedDescription }

        timer = Timer.scheduledTimer(withTimeInterval:0.25,repeats:true) { [weak self] _ in
            guard let self = self else { return }; self.bridge.checkTimeout()
            self.statusLabel.stringValue = startupError.map { "Could not start: \($0)" } ?? (self.bridge.connected ? "● Receiver connected · \(self.bridge.lastMessage)" : "○ Plug in your Harmonix Wii USB receiver to begin")
            self.statusLabel.textColor = startupError != nil ? .systemRed : (self.bridge.connected ? .systemGreen : .secondaryLabelColor)
            self.activityLabel.stringValue = "Reports: \(self.bridge.reports)     Notes sent: \(self.bridge.notes)     Held: \(self.bridge.heldCount)"
        }
        show()
    }
    func refreshOutputs() {
        output.removeAllItems()
        output.addItem(withTitle: Bridge.portName + " (own virtual port)")
        output.lastItem?.representedObject = NSNumber(value: 0)
        let destinations = bridge.destinations()
        for destination in destinations {
            output.addItem(withTitle: destination.name)
            output.lastItem?.representedObject = NSNumber(value: destination.id)
        }
        let saved = UserDefaults.standard.object(forKey: "MIDIDestinationID") as? NSNumber
        let preferred = saved?.int32Value ?? destinations.first(where: { $0.name == "IAC Driver Rock Band" })?.id ?? 0
        if preferred != 0 && !destinations.contains(where: { $0.id == preferred }) {
            output.addItem(withTitle: "Saved MIDI destination (unavailable)")
            output.lastItem?.representedObject = NSNumber(value: preferred)
        }
        if let index = output.itemArray.firstIndex(where: { ($0.representedObject as? NSNumber)?.int32Value == preferred }) {
            output.selectItem(at: index)
        }
        changeOutput()
    }
    @objc func reloadOutputs() { refreshOutputs() }
    @objc func help() { NSWorkspace.shared.open(URL(string:"https://github.com/RussCoty/rock-band-midi-bridge#quick-start")!) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    @objc func changeOutput() {
        guard let number = output.selectedItem?.representedObject as? NSNumber else { return }
        let id = number.int32Value
        bridge.setDestination(id == 0 ? nil : id)
    }
    @objc func changeSettings() { bridge.configure(base:(octave.indexOfSelectedItem+1)*12,channel:channel.indexOfSelectedItem,touchCC:[1,74,11][touch.indexOfSelectedItem]) }
    @objc func panic() { bridge.panic() }
    @objc func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { false }
    func applicationWillTerminate(_ notification:Notification) { timer?.invalidate(); bridge.stop() }
}
