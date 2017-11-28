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

// swiftlint:disable function_body_length

/// # An AVFoundation example to test our `AVAudioUnit`.
///
///
///
///
/// - author: Gene De Lisa
/// - copyright: 2016 Gene De Lisa
/// - date: February 2016
class SynthSequence: NSObject {
    
    var engine: AVAudioEngine!
    
    var sequencer: AVAudioSequencer!
    
    var midiSynth: AVAudioUnitMIDISynth!
    
    var patches = [UInt32]()
    
    let soundFontFileName = "FluidR3 GM2-2"
    let soundFontFileExt = "SF2"
    // there is a problem with a drop out using this soundfont
    //let soundFontFileName = "GeneralUser GS v1.471"
    //let soundFontFileExt = "sf2"

    
    override init() {
        super.init()
        
        engine = AVAudioEngine()
        

        midiSynth = AVAudioUnitMIDISynth()
        
        if let bankURL = Bundle.main.url(forResource: soundFontFileName, withExtension: soundFontFileExt) {
            midiSynth.loadMIDISynthSoundFont(bankURL)
            print("loading from url")
        } else {
            midiSynth.loadMIDISynthSoundFont()
        }
        
        let distortion = AVAudioUnitDistortionEffect()
        engine.attach(distortion)
        engine.connect(distortion, to: engine.mainMixerNode, format: nil)
        
        engine.attach(midiSynth)
        // with distortion
        engine.connect(midiSynth, to: distortion, format: nil)
        // without distortion
//        engine.connect(midiSynth, to: engine.mainMixerNode, format: nil)

        print("audio auaudiounit \(midiSynth.auAudioUnit)")
        print("audio audiounit \(midiSynth.audioUnit)")
        print("audio descr \(midiSynth.audioComponentDescription)")
        
        
        addObservers()

        startEngine()

        
        patches.append(0)
        patches.append(46) //harp
        
        // must be after the engine has started. Otherwise you will get kAudioUnitErr_Uninitialized
        do {
            try midiSynth.loadPatches(patches)
        } catch AVAudioUnitMIDISynthError.engineNotStarted {
            print("Start the engine first!")
            fatalError("setting patches")
        } catch let e as NSError {
            print("\(e)")
            print("\(e.localizedDescription)")
            fatalError("setting patches")
        }

        
        setupSequencer()
// or       setupSequencerFile()
        
        print(self.engine)
        
        // since we have created an AVAudioSequencer, the engine's musicSequence is set.
        CAShow(UnsafeMutablePointer<MusicSequence>(engine.musicSequence!))
        
        setSessionPlayback()
        
    }
    
    ///  Create an `AVAudioSequencer`.
    ///  The `MusicSequence` it uses is generated.
    func setupSequencer() {
        
        self.sequencer = AVAudioSequencer(audioEngine: self.engine)
        
        let options = AVMusicSequenceLoadOptions()
        let musicSequence = createMusicSequence()
        if let data = sequenceData(musicSequence) {
            do {
                try sequencer.load(from: data, options: options)
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

    ///  Create an `AVAudioSequencer`.
    ///  The `MusicSequence` it uses read from a standard MIDI file.
    func setupSequencerFile() {
        
        self.sequencer = AVAudioSequencer(audioEngine: self.engine)
        
        let options = AVMusicSequenceLoadOptions()
// or
//        if let fileURL = NSBundle.mainBundle().URLForResource("chromatic2", withExtension: "mid") {
//            do {
//                try sequencer.loadFromURL(fileURL, options: options)
//                print("loaded \(fileURL)")
//            } catch {
//                print("something screwed up \(error)")
//                return
//            }
//        }
        
        if let fileURL = Bundle.main.url(forResource: "The Legend of Zelda - Koji Kondo - Main Theme (King Meteor)", withExtension: "mid") {
            do {
                try sequencer.load(from: fileURL, options: options)
                print("loaded \(fileURL)")
            } catch {
                print("something screwed up \(error)")
                return
            }
        }
        
        sequencer.prepareToPlay()
        print(sequencer)
    }
    

    ///  `AVAudioSequencer` will not load a `MusicSequence`, but it will load `NSData`.
    ///
    ///  - parameter musicSequence: the `MusicSequence` that will be converted.
    ///
    ///  - returns: the `NSData` instance.
    func sequenceData(_ musicSequence: MusicSequence) -> Data? {
        var status = OSStatus(noErr)
        
        var data: Unmanaged<CFData>?
        status = MusicSequenceFileCreateData(musicSequence,
            MusicSequenceFileTypeID.midiType,
            MusicSequenceFileFlags.eraseFile,
            480, &data)
        if status != noErr {
            print("error turning MusicSequence into NSData")
            return nil
        }
        
        let ns: Data = data!.takeUnretainedValue() as Data
        data?.release()
        return ns
    }
    
    ///  Create a test `MusicSequence` with two tracks.
    ///
    ///  - returns: The `MusicSequence`.
    func createMusicSequence() -> MusicSequence {
        
        var musicSequence: MusicSequence? = nil
        var status = NewMusicSequence(&musicSequence)
        if status != noErr {
            print("\(#line) bad status \(status) creating sequence")
        }
        
        // add a track
        var track: MusicTrack? = nil
        status = MusicSequenceNewTrack(musicSequence!, &track)
        if status != noErr {
            print("error creating track \(status)")
        }
        
        var channel = UInt8(0)
        // bank select msb
        var chanmess = MIDIChannelMessage(status: 0xB0 | channel, data1: 0, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track!, 0, &chanmess)
        if status != noErr {
            print("creating bank select event \(status)")
        }
        // bank select lsb
        chanmess = MIDIChannelMessage(status: 0xB0 | channel, data1: 32, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track!, 0, &chanmess)
        if status != noErr {
            print("creating bank select event \(status)")
        }
        
        // program change. first data byte is the patch, the second data byte is unused for program change messages.
        chanmess = MIDIChannelMessage(status: 0xC0 | channel, data1: UInt8(0), data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track!, 0, &chanmess)
        if status != noErr {
            print("creating program change event \(status)")
        }
        
        // now make some notes and put them on the track
        var beat = MusicTimeStamp(0.0)
        for i: UInt8 in 60...72 {
            var mess = MIDINoteMessage(channel: channel,
                note: i,
                velocity: 64,
                releaseVelocity: 0,
                duration: 1.0 )
            status = MusicTrackNewMIDINoteEvent(track!, beat, &mess)
            if status != noErr {
                print("creating new midi note event \(status)")
            }
            beat += 1
        }
        
        // another track
        
        channel = UInt8(1)
        
        track  = nil
        status = MusicSequenceNewTrack(musicSequence!, &track)
        if status != noErr {
            print("error creating track \(status)")
        }
        
        chanmess = MIDIChannelMessage(status: 0xB0 | channel, data1: 0, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track!, 0, &chanmess)
        if status != noErr {
            print("creating bank select msb event \(status)")
        }
        
        chanmess = MIDIChannelMessage(status: 0xB0 | channel, data1: 32, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track!, 0, &chanmess)
        if status != noErr {
            print("creating bank select lsb event \(status)")
        }
        
        chanmess = MIDIChannelMessage(status: 0xC0 | channel, data1: UInt8(46), data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track!, 0, &chanmess)
        if status != noErr {
            print("creating program change event \(status)")
        }
        
        beat = MusicTimeStamp(3.0)
        for i: UInt8 in 60...72 {
            var mess = MIDINoteMessage(channel: channel,
                note: i,
                velocity: 36,
                releaseVelocity: 0,
                
                duration: 1.0 )
            status = MusicTrackNewMIDINoteEvent(track!, beat, &mess)
            if status != noErr {
                print("creating new midi note event \(status)")
            }
            beat += 1
        }
        
        // associate the AUGraph with the sequence.
        //status = MusicSequenceSetAUGraph(musicSequence, self.processingGraph)

        // don't do this
//        engine.musicSequence = musicSequence
        
        // Let's see it
        CAShow(UnsafeMutablePointer<MusicSequence>(musicSequence!))
        
        return musicSequence!
    }

    ///  Play the sequence.
    func play() {
        if sequencer.isPlaying {
            stop()
        }
        
        sequencer.currentPositionInBeats = TimeInterval(0)
        
        print("attempting to play")
        do {
            try sequencer.start()
            print("playing")
        } catch {
            print("cannot start \(error)")
        }
    }
    
    ///  Stop the sequence playing.
    func stop() {
        sequencer.stop()
    }
    
    ///  Put the `AVAudioSession` into playback mode and activate it.
    func setSessionPlayback() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try
                audioSession.setCategory(AVAudioSessionCategoryPlayback, with: AVAudioSessionCategoryOptions.mixWithOthers)
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
    
    ///  Start the `AVAudioEngine`
    func startEngine() {
        
        if engine.isRunning {
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
    
    // MARK: - Notifications
    
    func addObservers() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(SynthSequence.engineConfigurationChange(_:)),
            name: NSNotification.Name.AVAudioEngineConfigurationChange,
            object: engine)
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(SynthSequence.sessionInterrupted(_:)),
            name: NSNotification.Name.AVAudioSessionInterruption,
            object: engine)
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(SynthSequence.sessionRouteChange(_:)),
            name: NSNotification.Name.AVAudioSessionRouteChange,
            object: engine)
    }
    
    func removeObservers() {
        NotificationCenter.default.removeObserver(self,
            name: NSNotification.Name.AVAudioEngineConfigurationChange,
            object: nil)
        
        NotificationCenter.default.removeObserver(self,
            name: NSNotification.Name.AVAudioSessionInterruption,
            object: nil)
        
        NotificationCenter.default.removeObserver(self,
            name: NSNotification.Name.AVAudioSessionRouteChange,
            object: nil)
    }
    
    
    // MARK: notification callbacks
    @objc func engineConfigurationChange(_ notification: Notification) {
        print("engineConfigurationChange")
    }
    
    @objc func sessionInterrupted(_ notification: Notification) {
        print("audio session interrupted")
        if let engine = notification.object as? AVAudioEngine {
            engine.stop()
        }
        
        if let userInfo = (notification as NSNotification).userInfo as? [String: AnyObject?] {
            if let reason = userInfo[AVAudioSessionInterruptionTypeKey] as? AVAudioSessionInterruptionType {
                switch reason {
                case .began:
                    print("began")
                case .ended:
                    print("ended")
                }
            }
        }
    }
    
    @objc func sessionRouteChange(_ notification: Notification) {
        print("sessionRouteChange")
        if let engine = notification.object as? AVAudioEngine {
            engine.stop()
        }
        
        if let userInfo = (notification as NSNotification).userInfo as? [String: AnyObject?] {
            
            if let reason = userInfo[AVAudioSessionRouteChangeReasonKey] as? AVAudioSessionRouteChangeReason {
                
                print("audio session route change reason \(reason)")
                
                switch reason {
                case .categoryChange: print("CategoryChange")
                case .newDeviceAvailable:print("NewDeviceAvailable")
                case .noSuitableRouteForCategory:print("NoSuitableRouteForCategory")
                case .oldDeviceUnavailable:print("OldDeviceUnavailable")
                case .override: print("Override")
                case .wakeFromSleep:print("WakeFromSleep")
                case .unknown:print("Unknown")
                case .routeConfigurationChange:print("RouteConfigurationChange")
                }
            }
            
            let previous = userInfo[AVAudioSessionRouteChangePreviousRouteKey]
            print("audio session route change previous \(String(describing: previous))")
        }
    }
    
}
