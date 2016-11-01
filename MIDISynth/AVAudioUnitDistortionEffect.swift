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
 /// A multi-timbral implementation of `AVAudioUnitEffect` as an `AVAudioUnit`.
 /// This will use the `kAudioUnitSubType_Distortion` audio unit.
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
//


class AVAudioUnitDistortionEffect: AVAudioUnitEffect {
    
    override init() {
        var description                   = AudioComponentDescription()
        description.componentType         = kAudioUnitType_Effect
        description.componentSubType      = kAudioUnitSubType_Distortion
        description.componentManufacturer = kAudioUnitManufacturer_Apple
        description.componentFlags        = 0
        description.componentFlagsMask    = 0
        super.init(audioComponentDescription: description)
    }
    
    func setFinalMix(_ finalMix:Float) {

        let status = AudioUnitSetParameter(
            self.audioUnit,
            AudioUnitPropertyID(kDistortionParam_FinalMix),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            finalMix,
            0)
        
        if status != noErr {
            print("error \(status)")
        }
    }

    func setDelay(_ value:Float) {
        setAudioUnitParameterValue(audioUnit, parameterType: kDistortionParam_Delay, value: 0.0)
    }
    // etc for the rest
    
    
    func getAudioUnitParameterValue(_ audioUnit:AudioUnit , parameterType:AudioUnitParameterID ) -> Float {
        
        var value = AudioUnitParameterValue(0.0)
        let status = AudioUnitGetParameter(audioUnit,
                                           parameterType,
                                           kAudioUnitScope_Global,
                                           0,
                                           &value)
        if status == noErr {
            return value
        } else {
            return 0.0
        }
    }
    
    func setAudioUnitParameterValue(_ audioUnit:AudioUnit , parameterType:AudioUnitParameterID,  value:Float) {
        
        let status = AudioUnitSetParameter(audioUnit,
                                           parameterType,
                                           kAudioUnitScope_Global,
                                           0,
                                           value,
                                           0)
        if status != noErr {
            print("error \(status)")
        }
    }
}

/* other params
 
 kDistortionParam_Delay

 kDistortionParam_Decay

 kDistortionParam_DelayMix

 kDistortionParam_Decimation

 kDistortionParam_Rounding

 kDistortionParam_DecimationMix

 kDistortionParam_LinearTerm

 kDistortionParam_SquaredTerm

 kDistortionParam_CubicTerm

 kDistortionParam_PolynomialMix

 kDistortionParam_RingModFreq1

 kDistortionParam_RingModFreq2

 kDistortionParam_RingModBalance

 kDistortionParam_RingModMix

 kDistortionParam_SoftClipGain

 kDistortionParam_FinalMix


 
// range is from 0.1 to 500 milliseconds. Default is 0.1.
 delay

// range is from 0.1 to 50 (rate). Default is 1.0.
 decay

// range is from 0 to 100 (percentage). Default is 50.
 delayMix

// range is from 0% to 100%.
 decimation

// range is from 0% to 100%. Default is 0%.
 rounding

// range is from 0% to 100%. Default is 50%.
 decimationMix

// range is from 0 to 1 (linear gain). Default is 1.
 linearTerm

// range is from 0 to 20 (linear gain). Default is 0.
 squaredTerm

// range is from 0 to 20 (linear gain). Default is 0.
 cubicTerm

// range is from 0% to 100%. Default is 50%.
 polynomialMix

// range is from 0.5Hz to 8000Hz. Default is 100Hz.
 ringModFreq1

// range is from 0.5Hz to 8000Hz. Default is 100Hz.
 ringModFreq2

// range is from 0% to 100%. Default is 50%.
 ringModBalance

// range is from 0% to 100%. Default is 0%.
 ringModMix

// range is from -80dB to 20dB. Default is -6dB.
 softClipGain

// range is from 0% to 100%. Default is 50%.
 finalMix

*/
