//
//  AVAudioUnitMIDISynth.swift
//  MIDISynth
//
//  Created by Gene De Lisa on 2/6/16.
//  Copyright © 2016 Gene De Lisa. All rights reserved.
//

import Foundation
import AVFoundation


enum AVAudioUnitMIDISynthError: ErrorType {
    case EngineNotStarted
    case BadSoundFont
}


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
    
    func loadMIDISynthSoundFont()  {
        
        if let bankURL = NSBundle.mainBundle().URLForResource("FluidR3 GM2-2", withExtension: "SF2")  {
            loadMIDISynthSoundFont(bankURL)
            
//            let status = AudioUnitSetProperty(
//                self.audioUnit,
//                AudioUnitPropertyID(kMusicDeviceProperty_SoundBankURL),
//                AudioUnitScope(kAudioUnitScope_Global),
//                0,
//                &bankURL,
//                UInt32(sizeof(bankURL.dynamicType)))
//            
//            if status != OSStatus(noErr) {
//                print("error \(status)")
//            }
        } else {
            print("Could not load sound font")
        }
        print("loaded sound font")
    }
    
    func loadMIDISynthSoundFont(var bankURL:NSURL)  {
        
        let status = AudioUnitSetProperty(
            self.audioUnit,
            AudioUnitPropertyID(kMusicDeviceProperty_SoundBankURL),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &bankURL,
            UInt32(sizeof(bankURL.dynamicType)))
        
        if status != OSStatus(noErr) {
            print("error \(status)")
        }
        
        print("loaded sound font")
    }
    
    
    /**
     
     Turn on kAUMIDISynthProperty_EnablePreload so the midisynth will load the patch data from the file into memory.
     You load the patches first before playing a sequence or sending messages.
     Then you turn kAUMIDISynthProperty_EnablePreload off. It is now in a state where it will respond to MIDI program
     change messages and switch to the already cached instrument data.
     
     precondition: the graph must be initialized
     */
    
    func loadPatches(patches:[UInt32]) throws {
        
        if let e = engine {
            if !e.running {
                print("audio engine needs to be running")
                throw AVAudioUnitMIDISynthError.EngineNotStarted
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
            UInt32(sizeof(UInt32)))
        if status != OSStatus(noErr) {
            print("error \(status)")
        }
        //        let bankSelectCommand = UInt32(0xB0 | 0)
        //        status = MusicDeviceMIDIEvent(self.midisynthUnit, bankSelectCommand, 0, 0, 0)
        
        let pcCommand = UInt32(0xC0 | channel)
        for patch in patches {
            print("preloading patch \(patch)")
            status = MusicDeviceMIDIEvent(self.audioUnit, pcCommand, patch, 0, 0)
            if status != OSStatus(noErr) {
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
            UInt32(sizeof(UInt32)))
        if status != OSStatus(noErr) {
            print("error \(status)")
        }
        
        // at this point the patches are loaded. You still have to send a program change at "play time" for the synth
        // to switch to that patch
    }
}
