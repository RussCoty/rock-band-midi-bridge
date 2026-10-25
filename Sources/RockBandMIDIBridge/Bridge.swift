import Foundation
import CoreMIDI
import IOKit.hid

final class Bridge {
    static let portName = "Rock Band Wireless MIDI"
    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private var outputPort = MIDIPortRef()
    private(set) var destinationID: MIDIUniqueID?
    struct Destination { let id: MIDIUniqueID; let name: String }
    private var manager: IOHIDManager?
    private var buffers: [IOHIDDevice: UnsafeMutablePointer<UInt8>] = [:]
    private(set) var decoder = KeyboardDecoder()
    private(set) var reports = 0
    private(set) var notes = 0
    private(set) var lastMessage = "Waiting for a controller…"
    private(set) var lastReport = Date.distantPast
    var connected: Bool { !buffers.isEmpty }
    var heldCount: Int { decoder.heldCount }

    func start() throws {
        var status = MIDIClientCreateWithBlock("Rock Band Wireless Bridge" as CFString, &client) { _ in }
        guard status == noErr else { throw NSError(domain:"CoreMIDI",code:Int(status)) }
        status = MIDISourceCreate(client, Self.portName as CFString, &source)
        guard status == noErr else { throw NSError(domain:"CoreMIDI",code:Int(status)) }
        status = MIDIOutputPortCreate(client, "Rock Band output routing" as CFString, &outputPort)
        guard status == noErr else { throw NSError(domain:"CoreMIDI",code:Int(status)) }
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerSetDeviceMatching(manager!, [kIOHIDVendorIDKey: 0x1BAD, kIOHIDProductIDKey: 0x3330] as CFDictionary)
        IOHIDManagerRegisterDeviceMatchingCallback(manager!, { context, _, _, device in
            guard let context = context else { return }
            Unmanaged<Bridge>.fromOpaque(context).takeUnretainedValue().attach(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager!, { context, _, _, device in
            guard let context = context else { return }
            Unmanaged<Bridge>.fromOpaque(context).takeUnretainedValue().detach(device)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager!, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        status = IOHIDManagerOpen(manager!, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else { throw NSError(domain:"IOHID",code:Int(status)) }
    }

    private func attach(_ device: IOHIDDevice) {
        guard buffers[device] == nil else { return }
        guard buffers.isEmpty else { return } // Avoid mixing two keyboards' held-key states.
        let count = max(64, (IOHIDDeviceGetProperty(device, kIOHIDMaxInputReportSizeKey as CFString) as? NSNumber)?.intValue ?? 64)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        buffer.initialize(repeating: 0, count: count); buffers[device] = buffer
        IOHIDDeviceRegisterInputReportCallback(device, buffer, count, { context, result, _, _, reportID, data, length in
            guard let context = context, result == kIOReturnSuccess, reportID == 0 else { return }
            let bridge = Unmanaged<Bridge>.fromOpaque(context).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: data, count: length))
            guard bytes.count == 27 else { return }
            bridge.reports += 1; bridge.lastReport = Date()
            bridge.emit(bridge.decoder.process(bytes))
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        lastMessage = "Controller connected — play a note"
    }

    private func detach(_ device: IOHIDDevice) {
        guard let buffer = buffers.removeValue(forKey: device) else { return }
        panic()
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        // Device removal ends its callbacks before this main-run-loop handler returns.
        buffer.deallocate(); lastMessage = "Controller disconnected"
    }

    func destinations() -> [Destination] {
        (0..<MIDIGetNumberOfDestinations()).compactMap { index in
            let endpoint = MIDIGetDestination(index)
            var name: Unmanaged<CFString>?
            var uniqueID = MIDIUniqueID()
            guard MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID) == noErr,
                  MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) == noErr,
                  let name = name else { return nil }
            return Destination(id: uniqueID, name: name.takeRetainedValue() as String)
        }
    }
    func setDestination(_ id: MIDIUniqueID?) {
        guard id != destinationID else { return }
        panic() // Release on the old route before switching.
        destinationID = id
        if let id = id { UserDefaults.standard.set(Int(id), forKey: "MIDIDestinationID") }
        else { UserDefaults.standard.set(0, forKey: "MIDIDestinationID") }
        lastMessage = "Output route changed"
    }
    func configure(base: Int, channel: Int, touchCC: Int) {
        panic(); decoder.baseNote = min(96, max(12, base)); decoder.channel = min(15, max(0, channel)); decoder.touchCC = touchCC
    }
    func panic() { emit(decoder.flush()) }
    func checkTimeout() {
        if heldCount > 0 && Date().timeIntervalSince(lastReport) > 2 { panic(); lastMessage = "No reports for 2 seconds — notes released" }
    }
    private func emit(_ messages: [MIDIMessage]) {
        guard source != 0 else { return }
        for message in messages {
            let capacity = 1024
            let memory = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: MemoryLayout<MIDIPacketList>.alignment)
            defer { memory.deallocate() }
            let list = memory.bindMemory(to: MIDIPacketList.self, capacity: 1)
            let packet = MIDIPacketListInit(list)
            message.bytes.withUnsafeBufferPointer { bytes in
                _ = MIDIPacketListAdd(list, capacity, packet, 0, bytes.count, bytes.baseAddress!)
            }
            let status: OSStatus
            if let id = destinationID {
                var endpoint = MIDIObjectRef()
                var type = MIDIObjectType.other
                let found = MIDIObjectFindByUniqueID(id, &endpoint, &type)
                if found != noErr || type != .destination {
                    lastMessage = "Selected MIDI destination is unavailable"
                    continue
                }
                status = MIDISend(outputPort, MIDIEndpointRef(endpoint), list)
            } else {
                status = MIDIReceived(source, list)
            }
            if status != noErr { lastMessage = "MIDI send error \(status)"; continue }
            if message.bytes[0] & 0xF0 == 0x90 && message.bytes[2] > 0 { notes += 1 }
            lastMessage = message.description
            if ProcessInfo.processInfo.environment["RB_MIDI_LOG"] == "1" { print("MIDI \(message.bytes) \(message.description)"); fflush(stdout) }
        }
    }
    func stop() {
        panic()
        for device in buffers.keys { IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) }
        if let manager = manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
        for buffer in buffers.values { buffer.deallocate() }; buffers.removeAll(); manager = nil
        if outputPort != 0 { MIDIPortDispose(outputPort); outputPort = 0 }
        if source != 0 { MIDIEndpointDispose(source); source = 0 }
        if client != 0 { MIDIClientDispose(client); client = 0 }
    }
}
