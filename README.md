# ReaScripts
[Cotrino](http://www.cotrino.com/)'s scripts for Cockos REAPER DAW.

## External HW Synth Program Browser
Browser for programs (instrument patches) and arpeggios of your external hardware synthesizer. By selecting a program, inserts a MIDI media item in the selected track including the specific PC/CC/Sysex commands. This item is played automatically to generate an acoustic preview of each program/arpeggio combination. This is quite convenient to quickly browse settings in hardware synthesizers with tiny displays, but specially to keep those MIDI items with controller commands arranged within your song timeline, in order to dynamically change sounds on-the-fly.   
![Demo of the script in action with an external Yamaha MX88](https://raw.githubusercontent.com/cotrino/ReaScripts/master/gif/ext_synth_program_browser.gif)

How to use it:
1. Open the script in REAPER.
2. Create a track.
3. Arm track for recording.
4. Route track to your external MIDI device.
5. Choose Input MIDI: All MIDI Inputs -> All channels (or choose the correct channel).
6. Record monitoring: On.
7. Select track.
8. In the script UI, click on any program or arpeggio to preview the sound.

Note:
- This script requires [Scythe library v3](https://jalovatt.github.io/scythe/#/getting-started/installation).
- This script contains Yamaha-specific Sysex commands and has been tested with a [Yamaha MX88](https://es.yamaha.com/es/products/music_production/synthesizers/mx88/index.html) which belongs to the MOTIF XF series. If you use any other synth, please feel free to adapt the headers and/or extend the script.
- If you need deeper control of your hardware synthesizer, I'd recommend [John Melas MOTIF tools](http://www.jmelas.gr/motif/index.php). However, please note that they can't be integrated with REAPER and you may need to manually copy-paste or capture (e.g. using ReaControlMIDI VST) the low-level Sysex commands.
