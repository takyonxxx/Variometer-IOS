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
let insAudioGenerator: AudioGenerator = AudioGenerator()

class AudioGenerator{
    
    var player: AVAudioPlayerNode!
    var engine: AVAudioEngine!
   
    let bufferCapacity: AVAudioFrameCount = 8192
    let sampleRate: Double = 8000.0
    
    var frequency: Double = 700.0
    var amplitude: Double = 0.5
    
    private var theta: Double = 0.0
    private var audioFormat: AVAudioFormat!
    
    func setFrequency(newFreq : Double){
        frequency = newFreq
    }
    
    func Init(){
        
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        player = AVAudioPlayerNode()
        engine = AVAudioEngine()
        
        engine.attach(player)
        let mixer = engine.mainMixerNode
        engine.connect(player, to: mixer, format: audioFormat)
        
        if(!(engine.isRunning))
        {
            do {
                try engine.start()
            } catch let error as NSError {
                print(error)
            }
        }
    }
    
    func prepareBuffer() -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: bufferCapacity)
        fillBuffer(buffer!)
        return buffer!
    }
    
    func fillBuffer(_ buffer: AVAudioPCMBuffer) {
        
        let data = buffer.floatChannelData?[0]
        let numberFrames = buffer.frameCapacity
        var theta = self.theta
        let theta_increment = 2.0 * .pi * self.frequency / self.sampleRate
        
        for frame in 0..<Int(numberFrames) {
            data?[frame] = Float32(sin(theta) * amplitude)
            
            theta += theta_increment
            if theta > 2.0 * .pi {
                theta -= 2.0 * .pi
            }
        }
        buffer.frameLength = numberFrames
        self.theta = theta
    }
    
    func play() {
        
        let buffer = prepareBuffer()
        if(player.isPlaying)
        {
            player.stop()
        }
        player.play()
        player.scheduleBuffer(buffer, at: nil,options: .loops, completionHandler: nil)
    }
    
    func stop() {
        
        if(player.isPlaying)
        {
            player.stop()
        }
    }
    
    func deInit() {
        if(engine.isRunning)
        {
            engine.stop()
        }
    }
    
    class func sharedAudio() -> AudioGenerator {
        return insAudioGenerator
    }
}
