//
//  AssetWriter.swift
//  ConvertAgoraAudioToAVAudioAssetWriterFormat
//
//  Created by Shaun Hubbard on 4/5/23.
//

import AVKit
import AgoraRtcKit

class AssetWriter: NSObject, AgoraAudioFrameDelegate {
    
    var isRecording = false {
        didSet {
            if isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        }
    }
    
    private var assetWriter: AVAssetWriter? = nil
    private var assetWriterInput: AVAssetWriterInput? = nil
    private var currentURL: URL? = nil
    private var cmtime: CMTime {
        return CMClockGetTime(CMClockGetHostTimeClock())
    }
    
    private func startRecording() {
        let audioUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent((UUID().uuidString + ".m4a"))
        let writer = try! AVAssetWriter(url: audioUrl, fileType: .m4a)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100,
                                                                          
        ])
        if writer.canAdd(input) {
            writer.add(input)
        } else {
            fatalError("no input")
        }
        
        writer.startWriting()
        writer.startSession(atSourceTime: cmtime)
        
        assetWriter = writer
        assetWriterInput = input
        currentURL = audioUrl
    }
    
    private func stopRecording() {
        assetWriterInput?.markAsFinished()
        assetWriter?.finishWriting {
            self.assetWriter = nil
            self.assetWriterInput = nil
            print("stopped writing too \(self.currentURL!)")
        }
        
    }
    
    func onEarMonitoringAudioFrame(_ frame: AgoraAudioFrame) -> Bool {
        return true
    }
    
    func getEarMonitoringAudioParams() -> AgoraAudioParams {
        return AgoraAudioParams()
    }
    
    func getMixedAudioParams() -> AgoraAudioParams {
        return AgoraAudioParams()
    }
    func getRecordAudioParams() -> AgoraAudioParams {
        let params = AgoraAudioParams()
        params.sampleRate = 44_100
        params.mode = .readOnly
        params.channel = 1
        params.sampleRate = 1024
        
        return params
    }
    
    func getPlaybackAudioParams() -> AgoraAudioParams {
        return AgoraAudioParams()
    }
    
    func onMixedAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return true
    }
    

    func onRecordAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        if isRecording {            
            if let buffer = convert(frame: frame) {
                if assetWriterInput?.isReadyForMoreMediaData == true {
                    if assetWriterInput?.append(buffer) == false {
                        print("add failed")
                    }
                } else {
                    print("dumped frame writer not ready")
                }
            }
        }
        return true
    }
    
    func getObservedAudioFramePosition() -> AgoraAudioFramePosition {
        .record
    }
    
    func onRecord(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return true
    }
    
    func onPlaybackAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return true
    }

    
    func onPlaybackAudioFrame(beforeMixing frame: AgoraAudioFrame, channelId: String, uid: UInt) -> Bool {
        return true
    }
    
    private let audioChannelLayout =   AudioChannelLayout(mChannelLayoutTag: kAudioChannelLayoutTag_Mono,
                                                          mChannelBitmap: AudioChannelBitmap(),
                                                          mNumberChannelDescriptions: 0,
                                                          mChannelDescriptions: AudioChannelDescription())
    
    private func convert(frame: AgoraAudioFrame) -> CMSampleBuffer? {
        let channels = 1, sampleRate = 44_100, samplesPerCall = 1024
        var description
          = AudioStreamBasicDescription(mSampleRate: Float64(sampleRate),
                         mFormatID: kAudioFormatLinearPCM,
                         mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
                         mBytesPerPacket: 2 * UInt32(channels),
                         mFramesPerPacket: 1,
                         mBytesPerFrame: 2 * UInt32(channels),
                         mChannelsPerFrame: UInt32(channels),
                         mBitsPerChannel: 16,
                         mReserved: 0)
        var acl = audioChannelLayout
        var format: CMFormatDescription?
        CMAudioFormatDescriptionCreate(allocator: nil,
                        asbd: &description,
                        layoutSize: MemoryLayout<AudioChannelLayout>.size,
                        layout: &acl,
                        magicCookieSize: 0,
                        magicCookie: nil,
                        extensions: nil,
                        formatDescriptionOut: &format)
        var sampleTiming = CMSampleTimingInfo(duration: CMTimeMake(value: 1, timescale: Int32(sampleRate)),
                           presentationTimeStamp: cmtime,
                           decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreate(allocator: nil,
                   dataBuffer: nil,
                   dataReady: true,
                   makeDataReadyCallback: nil,
                   refcon: nil,
                   formatDescription: format,
                   sampleCount: Int(samplesPerCall),
                   sampleTimingEntryCount: 1,
                   sampleTimingArray: &sampleTiming,
                   sampleSizeEntryCount: 0,
                   sampleSizeArray: nil,
                   sampleBufferOut: &sampleBuffer)
        assert(frame.bufferSize == samplesPerCall * frame.bytesPerSample)
        guard let finalBuffer: UnsafeMutableRawPointer = frame.buffer else { return nil }
        let audioBuffer = AudioBuffer(mNumberChannels: UInt32(channels),
                                      mDataByteSize: frame.bufferSize,
                       mData: finalBuffer)
        var audioBufferList: AudioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
        CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer!,
                                blockBufferAllocator: nil,
                                blockBufferMemoryAllocator: nil,
                                flags: 0,
                                bufferList: &audioBufferList)
        return sampleBuffer
    }
    
}


extension AgoraAudioFrame {
    var bufferSize: UInt32 {
        return  UInt32(samplesPerChannel * channels * bytesPerSample)
    }
}
