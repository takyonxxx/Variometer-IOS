//
//  AudioGenerator.swift
//  Variometer
//
//  Created by Turkay Biliyor on 23/01/2018.
//  Copyright © 2018 Türkay Biliyor. All rights reserved.
//

import Foundation
import AVFoundation

//instance
let gAudioGenerator: AudioGenerator = AudioGenerator()

class AudioGenerator {
    
    // store persistent objects
    var audioEngine:AVAudioEngine
    var player:AVAudioPlayerNode
    var mixer:AVAudioMixerNode
    var buffer:AVAudioPCMBuffer
    
    init(){
        // initialize objects
        audioEngine = AVAudioEngine()
        player = AVAudioPlayerNode()
        mixer = audioEngine.mainMixerNode;
        buffer = AVAudioPCMBuffer(pcmFormat: player.outputFormat(forBus: 0), frameCapacity: 100)!
        buffer.frameLength = 100
        
        // setup audio engine
        audioEngine.attach(player)
        audioEngine.connect(player, to: mixer, format: player.outputFormat(forBus: 0))
        
        do {
            try audioEngine.start()
        } catch {
            print("AudioEngine didn't start")
        }
    }
    
    func play(carrierFrequency: Float32) {
        
        // generate sine wave
        let sr:Float = Float(mixer.outputFormat(forBus: 0).sampleRate)
        //let n_channels = mixer.outputFormat(forBus: 0).channelCount
        
        for var sampleIndex in 0 ..< Int(buffer.frameLength) {
            let val = sinf(carrierFrequency * Float(sampleIndex) * 2 * Float(Double.pi) / sr)
            
            buffer.floatChannelData?.pointee[sampleIndex] = val * 0.5
            sampleIndex = sampleIndex + 1
        }
        
        // play player and buffer
        player.play()
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }
    
    func stop() {
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }
    
    func engineStop(){
        
        if(audioEngine.isRunning){
             audioEngine.stop()
        }
    }
   
    @objc  func audioEngineConfigurationChange(_ notification: Notification) -> Void {
        NSLog("Audio engine configuration change: \(notification)")
    }
    
    class func sharedAudio() -> AudioGenerator {
        return gAudioGenerator
    }

}
