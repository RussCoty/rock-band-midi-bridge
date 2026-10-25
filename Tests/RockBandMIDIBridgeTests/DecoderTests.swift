import XCTest
@testable import RockBandMIDIBridge

final class DecoderTests: XCTestCase {
    func packet(_ keys:[Int]=[],_ velocities:[Int]=[],touch:Int=0,overdrive:Bool=false,pedal:Bool=false)->[UInt8] {
        var b=[UInt8](repeating:0,count:27); b[2]=8;b[3]=128;b[4]=128;b[14]=127
        for k in keys { if k<24 {b[5+k/8] |= UInt8(1 << (7-k%8))} else {b[8] |= 128} }
        for (slot,v) in velocities.prefix(5).enumerated() {b[8+slot] |= UInt8(v&127)}
        b[15]=UInt8(touch);if overdrive {b[13]=128};if pedal {b[14]|=128};return b
    }
    func noteOns(_ m:[MIDIMessage])->[[UInt8]] {m.filter{$0.bytes[0]&0xF0==0x90}.map(\.bytes)}
    func testAll25KeysAndRelease() {
        for k in 0..<25 {var d=KeyboardDecoder(); _=d.process(packet()); XCTAssertEqual(noteOns(d.process(packet([k],[95]))),[[0x90,UInt8(48+k),95]]); XCTAssertTrue(d.process(packet()).contains{$0.bytes==[0x80,UInt8(48+k),0]});XCTAssertEqual(d.heldCount,0)}
    }
    func testRepeatedUSBFramesDoNotRetrigger() {var d=KeyboardDecoder();_=d.process(packet([2],[70]));XCTAssertTrue(d.process(packet([2],[70])).isEmpty)}
    func testHeldKeyVelocitySlotsShiftWithoutRetrigger() {var d=KeyboardDecoder();_=d.process(packet([0,12],[40,90]));let result=d.process(packet([12],[90]));XCTAssertEqual(noteOns(result),[]);XCTAssertTrue(result.contains{$0.bytes==[0x80,48,0]});XCTAssertEqual(d.heldCount,1)}
    func testFiveNoteChordVelocities() {var d=KeyboardDecoder();XCTAssertEqual(noteOns(d.process(packet([0,4,7,12,24],[30,50,70,90,110]))).map{$0[2]},[30,50,70,90,110])}
    func testSixNoteChordUsesSafeVelocity() {var d=KeyboardDecoder();XCTAssertEqual(noteOns(d.process(packet([0,2,4,5,7,9],[30,40,50,60,70]))).map{$0[2]},[64,64,64,64,64,64])}
    func testZeroVelocityDoesNotBecomeNoteOff() {var d=KeyboardDecoder();XCTAssertEqual(noteOns(d.process(packet([0],[0]))),[[0x90,48,64]])}
    func testTouchStripAndOverdrive() {var d=KeyboardDecoder();_=d.process(packet());XCTAssertTrue(d.process(packet(touch:90)).contains{$0.bytes==[0xB0,1,90]});XCTAssertTrue(d.process(packet(touch:127,overdrive:true)).contains{$0.bytes==[0xE0,127,127]});XCTAssertTrue(d.process(packet(touch:0)).contains{$0.bytes==[0xE0,0,64]})}
    func testOverdriveWithoutTouchKeepsPitchCentred() {var d=KeyboardDecoder();_=d.process(packet());XCTAssertTrue(d.process(packet(overdrive:true)).contains{$0.bytes==[0xE0,0,64]})}
    func testCutoffMappingAndPedal() {var d=KeyboardDecoder();d.touchCC=74;XCTAssertTrue(d.process(packet(touch:70)).contains{$0.bytes==[0xB0,74,70]});XCTAssertTrue(d.process(packet(pedal:true)).contains{$0.bytes==[0xB0,64,127]});XCTAssertTrue(d.process(packet()).contains{$0.bytes==[0xB0,64,0]})}
    func testUnconnectedAnalogPedalNotSustain() {var d=KeyboardDecoder();XCTAssertFalse(d.process(packet()).contains{$0.bytes==[0xB0,64,127]})}
    func testFlushUsesOriginalNoteAndChannel() {var d=KeyboardDecoder();d.channel=2;_=d.process(packet([1],[70]));d.baseNote=60;d.channel=4;XCTAssertTrue(d.flush().contains{$0.bytes==[0x82,49,0]});XCTAssertEqual(d.heldCount,0)}
    func testPanicDoesNotRetriggerHeldKeys() {var d=KeyboardDecoder();_=d.process(packet([0],[80]));_=d.flush();XCTAssertEqual(noteOns(d.process(packet([0],[80]))),[]);_=d.process(packet());XCTAssertEqual(noteOns(d.process(packet([0],[90]))),[[0x90,48,90]])}
    func testShortOrDifferentReportsAreIgnored() {var d=KeyboardDecoder();XCTAssertTrue(d.process([0,0,0]).isEmpty);XCTAssertTrue(d.process([UInt8](repeating:0,count:28)).isEmpty)}
}
