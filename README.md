# Rock Band MIDI Bridge for macOS

**Turn a Harmonix Rock Band 3 Wii wireless keyboard into a MIDI controller.**

A small native Mac app that reads the keyboard's USB receiver and sends notes, velocity and expression to your DAW or software synth. No replacement USB driver, AAX wrapper or subscription needed. The app sends MIDI; it does not make sound itself.

**[Download the Mac app — ZIP](https://github.com/RussCoty/rock-band-midi-bridge/releases/download/v1.2.0/Rock-Band-MIDI-Bridge-1.2.0-macOS-universal.zip)** · [Release notes](https://github.com/RussCoty/rock-band-midi-bridge/releases/latest) · **[Report a problem](https://github.com/RussCoty/rock-band-midi-bridge/issues)**

## Compatibility

- **macOS 13 Ventura or later**, Apple Silicon and Intel (universal app).
- **Harmonix Rock Band 3 Wii wireless keyboard, item 96161**, with its matching USB receiver: vendor `0x1BAD`, product `0x3330`.
- Xbox, PlayStation and other receivers are **not supported by this release**. Pair the keyboard with its original matching receiver.
- Sends standard CoreMIDI, with selectable destination and a built-in virtual MIDI source.
- No network connection is used for MIDI. The Setup guide button opens this page in your browser.

## Install

1. Download `Rock-Band-MIDI-Bridge-1.2.0-macOS-universal.zip` from Releases and unzip it.
2. Drag **Rock Band MIDI Bridge.app** to Applications, then open it.
3. Plug in the receiver, power on and pair the keyboard. Look for **Receiver connected** and increasing report/note counters.

The release is **Developer ID signed and Apple notarized**, with the notarization ticket stapled to the app. Download, unzip, move it to Applications and open normally. macOS may show its standard first-open confirmation for an app downloaded from the internet; no Gatekeeper override is required. Organization-managed Macs may apply additional policies.

## Quick start

1. Choose your **MIDI output**. The app sends to exactly one route to avoid duplicate notes.
2. Set your DAW/instrument input to that source and the selected channel (default **1**).
3. Load an instrument, enable input monitoring or record-enable its track, then play.

For apps that recognize virtual sources, select **Rock Band Wireless MIDI (own virtual port)** in the bridge and **Rock Band Wireless MIDI** as the synth input.

### Pro Tools: use an Apple IAC bus

1. Open **Audio MIDI Setup**, choose **Window → Show MIDI Studio**, and double-click **IAC Driver**.
2. Enable **Device is online**. Add a bus named **Rock Band** and Apply. Keep any existing buses.
3. In the bridge, click **Refresh outputs**, then select **IAC Driver Rock Band**.
4. In Pro Tools, enable **IAC Driver Rock Band** under **Setup → MIDI → MIDI Input Devices**.
5. On an instrument track, choose that MIDI input/channel, load a synth such as Xpand!2 or Vacuum, and record-enable the track. For a MIDI track, route its output to a loaded synth.

Keep the bridge running while you play. Closing its window leaves it in the menu bar; **Quit** stops it. The app remembers the output route. A newly installed app prefers a bus named `IAC Driver Rock Band` if available, otherwise its own virtual source. It does not create or enable IAC buses automatically.

## Controls

| Control | What it does |
| --- | --- |
| MIDI output | Choose an existing CoreMIDI destination or the app's own virtual source. Refresh after adding a bus. |
| MIDI channel | Channels 1–16. |
| Lowest key | Transpose the 25-key range by octaves. Default MIDI 48–72; note numbers are definitive because DAW octave names differ. |
| Touch strip | Modulation CC1, filter cutoff CC74 or expression CC11. Map the chosen CC in your synth. |
| Overdrive button + strip | Pitch bend; releasing the button centres pitch. |
| Digital pedal | Sustain CC64. Analog expression pedals are not implemented. |
| Release all notes | Send note-offs, sustain-off and pitch centre. Held keys stay suppressed until released and pressed again. |

Changing channel, octave or output releases active notes first. Quitting, receiver removal and a two-second report timeout also release notes. The 250 ms status refresh does not gate MIDI: translation happens in the HID input callback.

## Troubleshooting

- **Waiting for receiver:** confirm you have the Wii receiver with the USB identifiers above; try reconnecting it. A connected receiver alone does not prove the keyboard is paired.
- **Reports but no notes:** power on and pair the keyboard; check the Notes sent counter while playing.
- **Notes sent but no sound:** this is a MIDI bridge, not a synth. Check DAW input enablement, track monitoring, MIDI channel, instrument and audio output. Some DAWs need to be reopened after a new MIDI source is created.
- **IAC missing:** enable the driver, Apply, then Refresh outputs. Other drivers' ports (including SSL V-MIDI) need their own routing; a destination and similarly named source are not necessarily a loopback pair.
- **Stuck sound:** use Release all notes; release the physical keys and pedal. A route that disappears before note-off may also need Panic in the receiving synth.

## Validation and limitations

13 automated decoder tests cover all 25 keys, note release, repeated frames, velocity-slot changes, five/six-note chords, malformed input, touch CCs, pedal flags, pitch centre and panic suppression. Live checks with a Wii controller confirmed low/middle/high C, soft/hard velocity, chords and touch CC1 through an independent CoreMIDI listener. Real keyboard notes also arrived through an IAC bus.

The report format carries only five velocity values. New notes in chords larger than five keys, or missing/zero attack readings, use velocity 64. Face buttons/D-pad shortcuts are not mapped. One matching receiver is handled at a time. Pedal hardware, overdrive pitch mode and unplugging while holding notes have not yet been physically verified. Intel builds are included but have not been run on Intel hardware.

The bridge reads HID non-exclusively and does not send feature/output reports, alter firmware, install a background service, or edit DAW sessions.

## Build

Requires macOS and an installed Swift toolchain / Xcode command-line tools.

```sh
swift test
swift build -c release
./scripts/package.sh
```

`package.sh` builds both architectures, creates the icon/app, ad-hoc signs by default, and writes a ZIP plus SHA-256 checksum under `dist/`. For Developer ID signing, set `SIGN_IDENTITY` to your own signing identity. Signing does not notarize the app. No third-party Swift dependencies are required.

### Notarizing a signed build

With valid Apple notarization credentials saved as a Keychain profile:

```sh
./scripts/notarize.sh YOUR_KEYCHAIN_PROFILE
```

The script submits the signed app archive to Apple, requires an `Accepted` result, staples and validates the ticket, checks Gatekeeper, and repackages the download with a new checksum. It does not upload to GitHub automatically. Apple may require the developer account holder to accept current agreements before submission. The public 1.2.0 download is signed and notarized; Gatekeeper assessment reports `source=Notarized Developer ID`.

## Protocol references

This Swift decoder was implemented from the documented report format and checked against captured 27-byte macOS HID reports.

- [PlasticBand: PS3/Wii keyboard report layout](https://github.com/TheNathannator/PlasticBand/blob/main/Docs/Instruments/Pro%20Keyboard/PS3%20and%20Wii.md)
- [PlasticBand: keyboard velocity-slot behaviour](https://github.com/TheNathannator/PlasticBand/blob/main/Docs/Instruments/Pro%20Keyboard/General%20Notes.md)
- [Earlier Windows USB-to-MIDI project](https://jasonharley2o.com/projects/rb/rb3keyboard/index.html)
- [Apple: transfer MIDI between apps with IAC](https://support.apple.com/guide/audio-midi-setup/transfer-midi-information-between-apps-ams1013/mac)

MIT licensed. Independent community software, not affiliated with or endorsed by Harmonix, Nintendo, Avid or Apple. Rock Band and other product names belong to their respective owners.
