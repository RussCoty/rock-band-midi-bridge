// swift-tools-version: 5.9
import PackageDescription
let package = Package(name:"RockBandMIDIBridge",platforms:[.macOS(.v13)],products:[.executable(name:"RockBandMIDIBridge",targets:["RockBandMIDIBridge"])],targets:[.executableTarget(name:"RockBandMIDIBridge"),.testTarget(name:"RockBandMIDIBridgeTests",dependencies:["RockBandMIDIBridge"])])
