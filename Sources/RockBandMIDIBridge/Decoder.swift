import Foundation

struct MIDIMessage: Equatable {
    let bytes: [UInt8]
    let description: String
}

/// macOS reports have no leading report-ID byte. The 25 key bits are big-endian
/// within bytes 5..8. Velocity slots are paired with held keys from left to right.
struct KeyboardDecoder {
    var baseNote = 48
    var channel = 0
    var touchCC = 1
    private var active: [Int: (note: Int, channel: Int)] = [:]
    private var blockedUntilRelease: Set<Int> = []
    private var lastTouch: Int?
    private var lastOverdrive = false
    private var lastPedal: Bool?
    var heldCount: Int { active.count }

    mutating func flush() -> [MIDIMessage] {
        var out = active.sorted(by: { $0.key < $1.key }).map {
            MIDIMessage(bytes: [UInt8(0x80 | $0.value.channel), UInt8($0.value.note), 0], description: "Note off \($0.value.note)")
        }
        out.append(.init(bytes: [UInt8(0xB0 | channel), 64, 0], description: "Sustain off"))
        out.append(.init(bytes: [UInt8(0xE0 | channel), 0, 64], description: "Pitch centred"))
        blockedUntilRelease.formUnion(active.keys)
        active.removeAll(); lastTouch = nil; lastOverdrive = false; lastPedal = nil
        return out
    }

    mutating func process(_ data: [UInt8]) -> [MIDIMessage] {
        guard data.count == 27 else { return [] }
        let bits = (UInt32(data[5]) << 17) | (UInt32(data[6]) << 9) | (UInt32(data[7]) << 1) | UInt32(data[8] >> 7)
        let pressed = (0..<25).filter { bits & (1 << (24 - $0)) != 0 }
        let pressedSet = Set(pressed)
        blockedUntilRelease.formIntersection(pressedSet)
        var out: [MIDIMessage] = []
        for key in active.keys.sorted() where !pressedSet.contains(key) {
            let old = active.removeValue(forKey: key)!
            out.append(.init(bytes: [UInt8(0x80 | old.channel), UInt8(old.note), 0], description: "Note off \(old.note)"))
        }
        for (slot, key) in pressed.enumerated() where active[key] == nil && !blockedUntilRelease.contains(key) {
            let pitch = min(127, max(0, baseNote + key))
            // The hardware only reports five velocities; don't mistake a missing
            // or zero contact reading for a note-off or a silent new note.
            let rawVelocity = slot < 5 && pressed.count <= 5 ? Int(data[8 + slot] & 0x7F) : 64
            let velocity = rawVelocity == 0 ? 64 : rawVelocity
            active[key] = (pitch, channel)
            out.append(.init(bytes: [UInt8(0x90 | channel), UInt8(pitch), UInt8(velocity)], description: "Note \(pitch) · velocity \(velocity)"))
        }
        let overdrive = data[13] & 0x80 != 0
        let touch = Int(data[15] & 0x7F)
        if touch != lastTouch || overdrive != lastOverdrive {
            if overdrive {
                let bend = touch == 0 ? 8192 : Int((Double(touch - 1) * 16383 / 126).rounded())
                out.append(.init(bytes: [UInt8(0xE0 | channel), UInt8(bend & 127), UInt8(bend >> 7)], description: "Pitch bend \(bend - 8192)"))
            } else {
                if lastOverdrive { out.append(.init(bytes: [UInt8(0xE0 | channel), 0, 64], description: "Pitch centred")) }
                out.append(.init(bytes: [UInt8(0xB0 | channel), UInt8(touchCC), UInt8(touch)], description: "CC\(touchCC) · \(touch)"))
            }
            lastTouch = touch; lastOverdrive = overdrive
        }
        // Only the digital pedal flag is mapped. Do not interpret the unconnected
        // analog value of 127 as a permanently depressed sustain pedal.
        let pedal = data[14] & 0x80 != 0
        if pedal != lastPedal {
            out.append(.init(bytes: [UInt8(0xB0 | channel), 64, pedal ? 127 : 0], description: pedal ? "Sustain on" : "Sustain off"))
            lastPedal = pedal
        }
        return out
    }
}
