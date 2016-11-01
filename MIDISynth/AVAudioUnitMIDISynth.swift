//
//  AVAudioUnitMIDISynth.swift
//  MIDISynth
//
//  Created by Gene De Lisa on 2/6/16.
//  Copyright © 2016 Gene De Lisa. All rights reserved.
//

import Foundation
import AVFoundation


 /// #An AVAudioUnit example.
 ///
 /// A multi-timbral implementation of `AVAudioUnitMIDIInstrument` as an `AVAudioUnit`.
 /// This will use the polyphonic `kAudioUnitSubType_MIDISynth` audio unit.
 ///
 /// - author: Gene De Lisa
 /// - copyright: 2016 Gene De Lisa
 /// - date: February 2016
 /// - requires: AVFoundation
 /// - seealso:
 ///[The Swift Standard Library Reference](https://developer.apple.com/library/prerelease/ios//documentation/General/Reference/SwiftStandardLibraryReference/index.html)
 ///
 /// - seealso:
 ///[Constructing Audio Unit Apps](https://developer.apple.com/library/ios/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide_iOS/ConstructingAudioUnitApps/ConstructingAudioUnitApps.html)
 ///
 /// - seealso:
 ///[Audio Unit Reference](https://developer.apple.com/library/ios/documentation/AudioUnit/Reference/AudioUnit_Framework/index.html)
class AVAudioUnitMIDISynth: AVAudioUnitMIDIInstrument {
    
    override init() {
        var description = AudioComponentDescription()
        description.componentType         = kAudioUnitType_MusicDevice
        description.componentSubType      = kAudioUnitSubType_MIDISynth
        description.componentManufacturer = kAudioUnitManufacturer_Apple
        description.componentFlags        = 0
        description.componentFlagsMask    = 0
        
        super.init(audioComponentDescription: description)
    }
    
    
    /// Loads the default sound font.
    /// If the file is not found, halt with an error message.
    func loadMIDISynthSoundFont()  {
        guard let bankURL = Bundle.main.url(forResource: "FluidR3 GM2-2", withExtension: "SF2")   else {
            fatalError("Get the default sound font URL correct!")
        }
        
        loadMIDISynthSoundFont(bankURL)
    }
    
    
    /// Loads the specified sound font.
    /// - parameter bankURL: A URL to the sound font.
    func loadMIDISynthSoundFont(_ bankURL:URL)  {
        var bankURL = bankURL
        
        let status = AudioUnitSetProperty(
            self.audioUnit,
            AudioUnitPropertyID(kMusicDeviceProperty_SoundBankURL),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &bankURL,
            UInt32(MemoryLayout<URL>.size))
        
        if status != OSStatus(noErr) {
            print("error \(status)")
        }
        
        print("loaded sound font")
    }
    
     /// Pre-load the patches you will use.
     ///
     /// Turn on `kAUMIDISynthProperty_EnablePreload` so the midisynth will load the patch data from the file into memory.
     /// You load the patches first before playing a sequence or sending messages.
     /// Then you turn `kAUMIDISynthProperty_EnablePreload` off. It is now in a state where it will respond to MIDI program
     /// change messages and switch to the already cached instrument data.
     ///
     /// - precondition: the graph must be initialized
     ///
     /// [Doug's post](http://prod.lists.apple.com/archives/coreaudio-api/2016/Jan/msg00018.html)
    func loadPatches(_ patches:[UInt32]) throws {
        
        if let e = engine {
            if !e.isRunning {
                print("audio engine needs to be running")
                throw AVAudioUnitMIDISynthError.engineNotStarted
            }
        }
        
        let channel = UInt32(0)
        var enabled = UInt32(1)
        
        var status = AudioUnitSetProperty(
            self.audioUnit,
            AudioUnitPropertyID(kAUMIDISynthProperty_EnablePreload),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &enabled,
            UInt32(MemoryLayout<UInt32>.size))
        if status != noErr {
            print("error \(status)")
        }
        //        let bankSelectCommand = UInt32(0xB0 | 0)
        //        status = MusicDeviceMIDIEvent(self.midisynthUnit, bankSelectCommand, 0, 0, 0)
        
        let pcCommand = UInt32(0xC0 | channel)
        for patch in patches {
            print("preloading patch \(patch)")
            status = MusicDeviceMIDIEvent(self.audioUnit, pcCommand, patch, 0, 0)
            if status != noErr {
                print("error \(status)")
                AudioUtils.CheckError(status)
            }
        }
        
        enabled = UInt32(0)
        status = AudioUnitSetProperty(
            self.audioUnit,
            AudioUnitPropertyID(kAUMIDISynthProperty_EnablePreload),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &enabled,
            UInt32(MemoryLayout<UInt32>.size))
        if status != noErr {
            print("error \(status)")
        }
        
        // at this point the patches are loaded. You still have to send a program change at "play time" for the synth
        // to switch to that patch
    }
}


/// Possible Errors for this `AVAudioUnit`.
///
/// - EngineNotStarted:
/// The AVAudioEngine needs to be started
///
/// - BadSoundFont:
/// The specified sound font is no good
enum AVAudioUnitMIDISynthError: Error {
    /// The AVAudioEngine needs to be started and it's not.
    case engineNotStarted
    /// The specified sound font is no good.
    case badSoundFont
}
