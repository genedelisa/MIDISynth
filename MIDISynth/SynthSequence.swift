//
//  AVSound.swift
//  MIDISynth
//
//  Created by Gene De Lisa on 2/6/16.
//  Copyright © 2016 Gene De Lisa. All rights reserved.
//


import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio


class SynthSequence : NSObject {
    
    var engine: AVAudioEngine!
    
    var sequencer:AVAudioSequencer!
    
    var midiSynth:AVAudioUnitMIDISynth!
    
    var patches = [UInt32]()
    
    override init() {
        super.init()
        
        engine = AVAudioEngine()
        

        midiSynth = AVAudioUnitMIDISynth()
        
        if let bankURL = NSBundle.mainBundle().URLForResource("FluidR3 GM2-2", withExtension: "SF2")  {
            midiSynth.loadMIDISynthSoundFont(bankURL)
            print("loading from url")
        } else {
            midiSynth.loadMIDISynthSoundFont()
        }
        
        
        engine.attachNode(midiSynth)
        engine.connect(midiSynth, to: engine.mainMixerNode, format: nil)

        print("audio auaudiounit \(midiSynth.AUAudioUnit)")
        print("audio audiounit \(midiSynth.audioUnit)")
        print("audio descr \(midiSynth.audioComponentDescription)")
        
        
        addObservers()

        startEngine()

        
        patches.append(0)
        patches.append(46)
        // must be after the engine has started. Otherwise you will get  kAudioUnitErr_Uninitialized
        do {
            try midiSynth.loadPatches(patches)
        } catch AVAudioUnitMIDISynthError.EngineNotStarted {
            print("Start the engine first!")
            fatalError("setting patches")
        } catch let e as NSError {
            print("\(e)")
            print("\(e.localizedDescription)")
            fatalError("setting patches")
        }

        
        setupSequencer()
//        setupSequencerFile()
        
        print(self.engine)
        
        // since we have created an AVAudioSequencer, the engine's musicSequence is set.
        CAShow(UnsafeMutablePointer<MusicSequence>(engine.musicSequence))

        
        setSessionPlayback()
        
    }
    
    func setupSequencer() {
        
        self.sequencer = AVAudioSequencer(audioEngine: self.engine)
        
        let options = AVMusicSequenceLoadOptions.SMF_PreserveTracks
        let musicSequence = createMusicSequence()
        if let data = sequenceData(musicSequence) {
            do {
                try sequencer.loadFromData(data, options: options)
                print("loaded \(data)")
            } catch {
                print("something screwed up \(error)")
                return
            }
            
        } else {
            print("nil data")
            return
        }
        
        sequencer.prepareToPlay()
        print(" loaded n \(sequencer.tracks.count) tracks")
    }
    
    func setupSequencerFile() {
        
        self.sequencer = AVAudioSequencer(audioEngine: self.engine)
        
        let options = AVMusicSequenceLoadOptions.SMF_PreserveTracks
        
//        if let fileURL = NSBundle.mainBundle().URLForResource("chromatic2", withExtension: "mid") {
//            do {
//                try sequencer.loadFromURL(fileURL, options: options)
//                print("loaded \(fileURL)")
//            } catch {
//                print("something screwed up \(error)")
//                return
//            }
//        }
        
        if let fileURL = NSBundle.mainBundle().URLForResource("The Legend of Zelda - Koji Kondo - Main Theme (King Meteor)", withExtension: "mid") {
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
    
    /**
     AVAudioSequencer will not load a MusicSequence, but it will load NSData.
     */
    func sequenceData(musicSequence:MusicSequence) -> NSData? {
        var status = OSStatus(noErr)
        
        var data:Unmanaged<CFData>?
        status = MusicSequenceFileCreateData(musicSequence,
            MusicSequenceFileTypeID.MIDIType,
            MusicSequenceFileFlags.EraseFile,
            480, &data)
        if status != noErr {
            print("error turning MusicSequence into NSData")
            return nil
        }
        
        let ns:NSData = data!.takeUnretainedValue()
        data?.release()
        return ns
    }
    
    func createMusicSequence() -> MusicSequence {
        
        var musicSequence = MusicSequence()
        var status = NewMusicSequence(&musicSequence)
        if status != OSStatus(noErr) {
            print("\(__LINE__) bad status \(status) creating sequence")
        }
        
        // add a track
        var track = MusicTrack()
        status = MusicSequenceNewTrack(musicSequence, &track)
        if status != OSStatus(noErr) {
            print("error creating track \(status)")
        }
        
        var channel = UInt8(0)
        // bank select msb
        var chanmess = MIDIChannelMessage(status: 0xB0 | channel, data1: 0, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track, 0, &chanmess)
        if status != OSStatus(noErr) {
            print("creating bank select event \(status)")
        }
        // bank select lsb
        chanmess = MIDIChannelMessage(status: 0xB0 | channel, data1: 32, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track, 0, &chanmess)
        if status != OSStatus(noErr) {
            print("creating bank select event \(status)")
        }
        
        // program change. first data byte is the patch, the second data byte is unused for program change messages.
        chanmess = MIDIChannelMessage(status: 0xC0 | channel, data1: UInt8(0), data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track, 0, &chanmess)
        if status != OSStatus(noErr) {
            print("creating program change event \(status)")
        }
        
        // now make some notes and put them on the track
        var beat = MusicTimeStamp(0.0)
        for i:UInt8 in 60...72 {
            var mess = MIDINoteMessage(channel: channel,
                note: i,
                velocity: 64,
                releaseVelocity: 0,
                duration: 1.0 )
            status = MusicTrackNewMIDINoteEvent(track, beat, &mess)
            if status != OSStatus(noErr) {
                print("creating new midi note event \(status)")
            }
            beat++
        }
        
        // another track
        
        channel = UInt8(1)
        
        track = MusicTrack()
        status = MusicSequenceNewTrack(musicSequence, &track)
        if status != OSStatus(noErr) {
            print("error creating track \(status)")
        }
        
        chanmess = MIDIChannelMessage(status: 0xB0 | channel, data1: 0, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track, 0, &chanmess)
        if status != OSStatus(noErr) {
            print("creating bank select msb event \(status)")
        }
        
        chanmess = MIDIChannelMessage(status: 0xB0 | channel, data1: 32, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track, 0, &chanmess)
        if status != OSStatus(noErr) {
            print("creating bank select lsb event \(status)")
        }
        
        chanmess = MIDIChannelMessage(status: 0xC0 | channel, data1: UInt8(46), data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track, 0, &chanmess)
        if status != OSStatus(noErr) {
            print("creating program change event \(status)")
        }
        
        beat = MusicTimeStamp(3.0)
        for i:UInt8 in 60...72 {
            var mess = MIDINoteMessage(channel: channel,
                note: i,
                velocity: 36,
                releaseVelocity: 0,
                
                duration: 1.0 )
            status = MusicTrackNewMIDINoteEvent(track, beat, &mess)
            if status != OSStatus(noErr) {
                print("creating new midi note event \(status)")
            }
            beat++
        }
        
        // associate the AUGraph with the sequence.
        //status = MusicSequenceSetAUGraph(musicSequence, self.processingGraph)

        // don't do this
//        engine.musicSequence = musicSequence
        
        // Let's see it
        CAShow(UnsafeMutablePointer<MusicSequence>(musicSequence))
        
        return musicSequence
    }

    
    func play() {
        if sequencer.playing {
            stop()
        }
        
        sequencer.currentPositionInBeats = NSTimeInterval(0)
        
        print("attempting to play")
        do {
            try sequencer.start()
            print("playing")
        } catch {
            print("cannot start \(error)")
        }
    }
    
    func stop() {
        sequencer.stop()
    }
    
    func setSessionPlayback() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try
                audioSession.setCategory(AVAudioSessionCategoryPlayback, withOptions: AVAudioSessionCategoryOptions.MixWithOthers)
        } catch {
            print("couldn't set category \(error)")
            return
        }
        
        do {
            try audioSession.setActive(true)
        } catch {
            print("couldn't set category active \(error)")
            return
        }
    }
    
    func startEngine() {
        
        if engine.running {
            print("audio engine already started")
            return
        }
        
        do {
            try engine.start()
            print("audio engine started")
        } catch {
            print("oops \(error)")
            print("could not start audio engine")
        }
    }
    
    //MARK: - Notifications
    
    func addObservers() {
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"engineConfigurationChange:",
            name:AVAudioEngineConfigurationChangeNotification,
            object:engine)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"sessionInterrupted:",
            name:AVAudioSessionInterruptionNotification,
            object:engine)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"sessionRouteChange:",
            name:AVAudioSessionRouteChangeNotification,
            object:engine)
    }
    
    func removeObservers() {
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name: AVAudioEngineConfigurationChangeNotification,
            object: nil)
        
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name: AVAudioSessionInterruptionNotification,
            object: nil)
        
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name: AVAudioSessionRouteChangeNotification,
            object: nil)
    }
    
    
    // MARK: notification callbacks
    func engineConfigurationChange(notification:NSNotification) {
        print("engineConfigurationChange")
    }
    
    func sessionInterrupted(notification:NSNotification) {
        print("audio session interrupted")
        if let engine = notification.object as? AVAudioEngine {
            engine.stop()
        }
        
        if let userInfo = notification.userInfo as? Dictionary<String,AnyObject!> {
            let reason = userInfo[AVAudioSessionInterruptionTypeKey] as! AVAudioSessionInterruptionType
            switch reason {
            case .Began:
                print("began")
            case .Ended:
                print("ended")
            }
        }
    }
    
    func sessionRouteChange(notification:NSNotification) {
        print("sessionRouteChange")
        if let engine = notification.object as? AVAudioEngine {
            engine.stop()
        }
        
        if let userInfo = notification.userInfo as? Dictionary<String,AnyObject!> {
            
            if let reason = userInfo[AVAudioSessionRouteChangeReasonKey] as? AVAudioSessionRouteChangeReason {
                
                print("audio session route change reason \(reason)")
                
                switch reason {
                case .CategoryChange: print("CategoryChange")
                case .NewDeviceAvailable:print("NewDeviceAvailable")
                case .NoSuitableRouteForCategory:print("NoSuitableRouteForCategory")
                case .OldDeviceUnavailable:print("OldDeviceUnavailable")
                case .Override: print("Override")
                case .WakeFromSleep:print("WakeFromSleep")
                case .Unknown:print("Unknown")
                case .RouteConfigurationChange:print("RouteConfigurationChange")
                }
            }
            
            let previous = userInfo[AVAudioSessionRouteChangePreviousRouteKey]
            print("audio session route change previous \(previous)")
        }
    }
    
}
