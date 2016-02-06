//
//  AudioUnitMIDISynth.swift
//  MIDISynth
//
//  Created by Gene De Lisa on 2/6/16.
//  Copyright © 2016 Gene De Lisa. All rights reserved.
//


import Foundation
import AudioToolbox
import AVFoundation
import CoreAudio

class AudioUnitMIDISynth : NSObject {
    
    var processingGraph:AUGraph
    var samplerNode:AUNode
    var midisynthNode = AUNode()
    var ioNode:AUNode
    var samplerUnit:AudioUnit
    var midisynthUnit = AudioUnit()
    var ioUnit:AudioUnit
    var isPlaying:Bool
    var toneUnit:AudioComponentInstance
    
    override init() {
        self.processingGraph = AUGraph()
        self.samplerNode = AUNode()
        self.ioNode = AUNode()
        self.samplerUnit  = AudioUnit()
        self.ioUnit  = AudioUnit()
        self.isPlaying = false
        self.toneUnit = AudioComponentInstance()
        super.init()
        
        //        engine = AVAudioEngine()
        //        setupSequencer()
        
        augraphSetup()
        //        loadSF2Preset(5)
        
        
        loadMIDISynthSoundFont()
        initializeGraph()
        loadPatches()
        startGraph()
        
    }
    
    
    func augraphSetup() {
        var status = OSStatus(noErr)
        status = NewAUGraph(&processingGraph)
        CheckError(status)
        
        //        var cd = AudioComponentDescription(
        //            componentType: OSType(kAudioUnitType_MusicDevice),
        //            componentSubType: OSType(kAudioUnitSubType_Sampler),
        //            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
        //            componentFlags: 0,componentFlagsMask: 0)
        //        status = AUGraphAddNode(self.processingGraph, &cd, &samplerNode)
        //        CheckError(status)
        
        var ioUnitDescription = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_Output),
            componentSubType: OSType(kAudioUnitSubType_RemoteIO),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,componentFlagsMask: 0)
        status = AUGraphAddNode(self.processingGraph, &ioUnitDescription, &ioNode)
        CheckError(status)
        
        createSynth()
        
        // now do the wiring. The graph needs to be open before you call AUGraphNodeInfo
        status = AUGraphOpen(self.processingGraph)
        CheckError(status)
        
        //        status = AUGraphNodeInfo(self.processingGraph, self.samplerNode, nil, &samplerUnit)
        //        CheckError(status)
        
        status = AUGraphNodeInfo(self.processingGraph, self.midisynthNode, nil, &midisynthUnit)
        CheckError(status)
        
        status = AUGraphNodeInfo(self.processingGraph, self.ioNode, nil, &ioUnit)
        CheckError(status)
        
        
        let ioUnitOutputElement:AudioUnitElement = 0
        let samplerOutputElement:AudioUnitElement = 0
        //        status = AUGraphConnectNodeInput(self.processingGraph,
        //            self.samplerNode, samplerOutputElement, // srcnode, inSourceOutputNumber
        //            self.ioNode, ioUnitOutputElement) // destnode, inDestInputNumber
        
        status = AUGraphConnectNodeInput(self.processingGraph,
            self.midisynthNode, samplerOutputElement, // srcnode, inSourceOutputNumber
            self.ioNode, ioUnitOutputElement) // destnode, inDestInputNumber
        
        CheckError(status)
    }
    
    
    
    
    //    To use the MIDISynth AU, you need to include a SoundFont 2 (.sf2) or Downloadable Sounds (.dls) bank file with your app.
    //    When you first set up your AU, pass it the URL for the bank file using the kMusicDeviceProperty_SoundBankURL property.  This is different that what the Sampler AU does with samples -- here, you are passing it the specific path using [NSBundle bundleForClass: pathForResource:].
    //
    //    The MIDISynth loads instrument presets out of the bank you specify in response to program change messages in your MIDI file.  If you use the MIDISynth in conjunction with the MusicPlayer/Sequence API, it will take care of the extra step you will need to pre-load all the instruments during the preroll stage, before you start playing.
    //
    //    If you goal is straightforward MIDI file playback, I *strongly* recommend the new AVMIDIPlayer which is part of the AVFoundation audio API.  This lets you get away from the older C-based APIs completely.
    //
    //    The other possibility, if you need more flexibility, is the new iOS 9 AVAudioSequencer plus the AVAudioEngine.  You can create an Instrument Node for the Engine which contains an AUMIDISynth instance.  Check out the 2015 WWDC talk which touches on this.
    //
    //
    
    func createSynth() {
        var cd = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_MusicDevice),
            componentSubType: OSType(kAudioUnitSubType_MIDISynth),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,componentFlagsMask: 0)
        let status = AUGraphAddNode(self.processingGraph, &cd, &midisynthNode)
        CheckError(status)
    }
    
    func createSampler() {
        var status = OSStatus(noErr)
        var cd = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_MusicDevice),
            componentSubType: OSType(kAudioUnitSubType_Sampler),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,componentFlagsMask: 0)
        status = AUGraphAddNode(self.processingGraph, &cd, &samplerNode)
        CheckError(status)
    }
    
    /// loads preset into self.samplerUnit
    func loadSF2Preset(preset:UInt8)  {
        
        guard let bankURL = NSBundle.mainBundle().URLForResource("GeneralUser GS MuseScore v1.442", withExtension: "sf2") else {
            fatalError("cannot open soundfont")
        }
        
        var instdata = AUSamplerInstrumentData(fileURL: Unmanaged.passUnretained(bankURL),
            instrumentType: UInt8(kInstrumentType_SF2Preset),
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB),
            presetID: preset)
        
        
        let status = AudioUnitSetProperty(
            self.samplerUnit,
            AudioUnitPropertyID(kAUSamplerProperty_LoadInstrument),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &instdata,
            UInt32(sizeof(AUSamplerInstrumentData)))
        CheckError(status)
        
    }
    
    func loadMIDISynthSoundFont()  {
        
       
        
        
        //        if var bankURL = NSBundle.mainBundle().URLForResource("GeneralUser GS MuseScore v1.442", withExtension: "sf2")  {
        if var bankURL = NSBundle.mainBundle().URLForResource("FluidR3 GM2-2", withExtension: "SF2")  {
            
            let status = AudioUnitSetProperty(
                self.midisynthUnit,
                AudioUnitPropertyID(kMusicDeviceProperty_SoundBankURL),
                AudioUnitScope(kAudioUnitScope_Global),
                0,
                &bankURL,
                UInt32(sizeof(NSURL)))
//                UInt32(sizeof(bankURL.dynamicType)))
            
            CheckError(status)
        } else {
            print("Could not load sound font")
        }
        print("loaded sound font")
        
        
       
        
        
    }

    func loadPatches() {
        if !isGraphInitialized() {
            fatalError("initialize graph first")
        }
        
        var enabled = UInt32(1)
        var status = AudioUnitSetProperty(
            self.midisynthUnit,
            AudioUnitPropertyID(kAUMIDISynthProperty_EnablePreload),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &enabled,
            UInt32(sizeof(UInt32)))
        CheckError(status)
        
        //        let bankSelectCommand = UInt32(0xB0 | 0)
        //        status = MusicDeviceMIDIEvent(self.midisynthUnit, bankSelectCommand, 0, 0, 0)
        
        let pcCommand = UInt32(0xC0 | 0)
        status = MusicDeviceMIDIEvent(self.midisynthUnit, pcCommand, 53, 0, 0)
        CheckError(status)
        
        enabled = UInt32(0)
        status = AudioUnitSetProperty(
            self.midisynthUnit,
            AudioUnitPropertyID(kAUMIDISynthProperty_EnablePreload),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &enabled,
            UInt32(sizeof(UInt32)))
        CheckError(status)
        
        // again!
        status = MusicDeviceMIDIEvent(self.midisynthUnit, pcCommand, 53, 0, 0)
        CheckError(status)

    }
    
    
     //https://developer.apple.com/library/prerelease/ios/documentation/AudioToolbox/Reference/AUGraphServicesReference/index.html#//apple_ref/c/func/AUGraphIsInitialized
    func isGraphInitialized() -> Bool {
        var outIsInitialized = DarwinBoolean(false)
        let status = AUGraphIsInitialized(self.processingGraph, &outIsInitialized)
        CheckError(status)
        return Bool(outIsInitialized)
    }
    
    func initializeGraph() {
        let status = AUGraphInitialize(self.processingGraph)
        CheckError(status)
    }
    
    func startGraph() {
        let status = AUGraphStart(self.processingGraph)
        CheckError(status)
    }
    
    func isGraphRunning() -> Bool {
        var isRunning = DarwinBoolean(false)
        let status = AUGraphIsRunning(self.processingGraph, &isRunning)
        CheckError(status)
        return Bool(isRunning)
    }
    
    
    var pitch = UInt32(60)
    func playNoteOn(noteNum:UInt32, velocity:UInt32)    {
        
        let noteCommand:UInt32 = 0x90 | 0
        var status = OSStatus(noErr)
        
        
        pitch = arc4random_uniform(100) + 36
        print(pitch)

        
        status = MusicDeviceMIDIEvent(self.midisynthUnit, noteCommand, pitch, velocity, 0)
        //        status = MusicDeviceMIDIEvent(self.samplerUnit, noteCommand, noteNum, velocity, 0)
        CheckError(status)
        print("noteon status is \(status)")
    }
    
    func playNoteOff(noteNum:UInt32)    {
        let noteCommand:UInt32 = 0x80 | 0
        var status : OSStatus = OSStatus(noErr)
        status = MusicDeviceMIDIEvent(self.midisynthUnit, noteCommand, pitch, 0, 0)
        //        status = MusicDeviceMIDIEvent(self.samplerUnit, noteCommand, noteNum, 0, 0)
        CheckError(status)
        print("noteoff status is \(status)")
    }
    
    
    //MARK : AvFoundation guff
    
    var engine: AVAudioEngine!
    
    var sequencer:AVAudioSequencer!
    
    func setupSequencer() {
        
        self.sequencer = AVAudioSequencer(audioEngine: self.engine)
        
        let options = AVMusicSequenceLoadOptions.SMF_PreserveTracks
        if let fileURL = NSBundle.mainBundle().URLForResource("chromatic2", withExtension: "mid") {
            do {
                try sequencer.loadFromURL(fileURL, options: options)
                print("loaded \(fileURL)")
            } catch {
                print("something screwed up \(error)")
                return
            }
        }
        
        sequencer.prepareToPlay()
        print(sequencer)
    }
    
    func play() {
        if sequencer.playing {
            stop()
        }
        
        sequencer.currentPositionInBeats = NSTimeInterval(0)
        
        do {
            try sequencer.start()
        } catch {
            print("cannot start \(error)")
        }
    }
    
    func stop() {
        sequencer.stop()
    }
    
}
