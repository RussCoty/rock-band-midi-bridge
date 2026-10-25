import AppKit
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels)/512, y: CGFloat(pixels)/512)
        NSColor(calibratedRed:0.06,green:0.09,blue:0.16,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:8,y:8,width:496,height:496),xRadius:104,yRadius:104).fill()
        NSColor(calibratedRed:0.20,green:0.89,blue:0.75,alpha:1).setFill()
        let text = "MIDI" as NSString
        text.draw(at:NSPoint(x:80,y:304),withAttributes:[.font:NSFont.systemFont(ofSize:94,weight:.heavy),.foregroundColor:NSColor(calibratedRed:0.20,green:0.89,blue:0.75,alpha:1)])
        for key in 0..<7 {
            NSColor.white.setFill()
            NSBezierPath(roundedRect:NSRect(x:65+CGFloat(key)*55,y:104,width:48,height:160),xRadius:6,yRadius:6).fill()
        }
        for key in [0,1,3,4,5] {
            NSColor(calibratedRed:0.06,green:0.09,blue:0.16,alpha:1).setFill()
            NSBezierPath(roundedRect:NSRect(x:98+CGFloat(key)*55,y:179,width:34,height:85),xRadius:4,yRadius:4).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:destination+"/icon_\(size)x\(size)\(suffix).png"))
    }
}
