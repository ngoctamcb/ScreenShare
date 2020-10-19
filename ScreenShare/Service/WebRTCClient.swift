//
//  WebRTCClient.swift
//  ScreenShare
//
//  Created by Tran Ngoc Tam on 10/9/20.
//  Copyright © 2020 Tran Ngoc Tam. All rights reserved.
//

import Foundation
import WebRTC
import ReplayKit
import VideoToolbox

protocol WebRTCClientDelegate: class {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate, peerConnectionType: PeerConnectionType)
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState, peerConnectionType: PeerConnectionType)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
}

final class WebRTCClient: RPBroadcastSampleHandler {
    
    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
    // A new RTCPeerConnection should be created every new call, but the factory is shared.
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
        
    weak var delegate: WebRTCClientDelegate?
    let peerConnection: RTCPeerConnection
    let screenSharePeerConnection: RTCPeerConnection
    private let rtcAudioSession =  RTCAudioSession.sharedInstance()
    private let audioQueue = DispatchQueue(label: "audio")
    private let mediaConstrains = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                                   kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
    let screenShareMediaConstrains = [kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
    var videoCapturer: RTCVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var localDataChannel: RTCDataChannel?
    private var remoteDataChannel: RTCDataChannel?
    
    var videoSource: RTCVideoSource?

    @available(*, unavailable)
    override init() {
        fatalError("WebRTCClient:init is unavailable")
    }
    
    required init(iceServers: [String]) {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: iceServers)]
        
        // Unified plan is more superior than planB
        config.sdpSemantics = .unifiedPlan
        
        // gatherContinually will let WebRTC to listen to any network changes and send any new candidates to the other client
        config.continualGatheringPolicy = .gatherContinually
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
        self.peerConnection = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil)
        
        self.screenSharePeerConnection = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil)

        super.init()
        self.createMediaSenders()
        self.configureAudioSession()
        self.peerConnection.delegate = self
        self.screenSharePeerConnection.delegate = self
    }
    
    // MARK: Signaling
    func offer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
                                             optionalConstraints: nil)
        self.peerConnection.offer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            
            self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                AppGroupUserDefault.shared.storeLocalSdpString(sdp: sdp.sdp)
                completion(sdp)
            })
        }
    }
    
    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void)  {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
                                             optionalConstraints: nil)
        self.peerConnection.answer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }

            self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                AppGroupUserDefault.shared.storeLocalSdpString(sdp: sdp.sdp)
                completion(sdp)
            })
        }
    }
    
    func set(remoteSdp: RTCSessionDescription, peerConnectionType: PeerConnectionType, completion: @escaping (Error?) -> ()) {
        switch peerConnectionType {
        case .main:
            self.peerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
            AppGroupUserDefault.shared.storeRemoteSdp(sdp: remoteSdp.sdp)
        case .screenShare:
            self.screenSharePeerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
        }
    }
    
    func set(remoteCandidate: RTCIceCandidate, peerConnectionType: PeerConnectionType) {
        switch peerConnectionType {
        case .main:
            self.peerConnection.add(remoteCandidate)
        case .screenShare:
            self.screenSharePeerConnection.add(remoteCandidate)
        }
    }
    
    // MARK: Media
    func startCaptureLocalVideo(renderer: RTCVideoRenderer) {
//        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else {
//            return
//        }
//
//        guard
//            let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }),
//
//            // choose highest res
//            let format = (RTCCameraVideoCapturer.supportedFormats(for: frontCamera).sorted { (f1, f2) -> Bool in
//                let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
//                let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
//                return width1 < width2
//            }).last,
//
//            // choose highest fps
//            let fps = (format.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else {
//            return
//        }
//
//        capturer.startCapture(with: frontCamera,
//                              format: format,
//                              fps: Int(fps.maxFrameRate))
//
//        self.localVideoTrack?.add(renderer)
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        
        
        switch sampleBufferType {
            case RPSampleBufferType.video:
                // Handle video sample buffer
                guard let pixelBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                     break
                 }
                 let rtcpixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
                 let timeStampNs: Int64 = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000000000)
                 let videoFrame = RTCVideoFrame(buffer: rtcpixelBuffer, rotation: RTCVideoRotation._0, timeStampNs: timeStampNs)
                
                self.videoSource!.capturer(self.videoCapturer!, didCapture: videoFrame)
                break
            case RPSampleBufferType.audioApp:
                // Handle audio sample buffer for app audio

                break
            case RPSampleBufferType.audioMic:
                // Handle audio sample buffer for mic audio
                break
            @unknown default:
                break
            }
    }
    
    
    
    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        self.remoteVideoTrack?.add(renderer)
    }
    
    private func configureAudioSession() {
        self.rtcAudioSession.lockForConfiguration()
        do {
            try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        } catch let error {
            debugPrint("Error changeing AVAudioSession category: \(error)")
        }
        self.rtcAudioSession.unlockForConfiguration()
    }
    
    private func createMediaSenders() {
        let streamId = "stream"
        
//         Audio
        let audioTrack = self.createAudioTrack()
        self.peerConnection.add(audioTrack, streamIds: [streamId])
        
        // Video
        let videoTrack = self.createVideoTrack()
        self.localVideoTrack = videoTrack
        self.screenSharePeerConnection.add(videoTrack, streamIds: [streamId])
        self.remoteVideoTrack = self.screenSharePeerConnection.transceivers.first { $0.mediaType == .video }?.receiver.track as? RTCVideoTrack
        
        // Data
        if let dataChannel = createDataChannel() {
            dataChannel.delegate = self
            self.localDataChannel = dataChannel
        }
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = WebRTCClient.factory.audioSource(with: audioConstrains)
        let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: "audio0")
        return audioTrack
    }
    
    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = WebRTCClient.factory.videoSource()
                
        #if TARGET_OS_SIMULATOR
        self.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
//        self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif
        
        self.videoCapturer = RTCVideoCapturer(delegate: videoSource)
        
        let videoTrack = WebRTCClient.factory.videoTrack(with: videoSource, trackId: "video0")
        self.videoSource = videoSource
        return videoTrack
    }
    
    // MARK: Data Channels
    private func createDataChannel() -> RTCDataChannel? {
        let config = RTCDataChannelConfiguration()
        guard let dataChannel = self.peerConnection.dataChannel(forLabel: "WebRTCData", configuration: config) else {
            debugPrint("Warning: Couldn't create data channel.")
            return nil
        }
        return dataChannel
    }
    
    func sendData(_ data: Data) {
        let buffer = RTCDataBuffer(data: data, isBinary: true)
        self.remoteDataChannel?.sendData(buffer)
    }
    
    
    
    func screenShare(renderer: RTCVideoRenderer){
        startScreenShare(videoSource: self.videoSource!, videoCapture: self.videoCapturer!)
        
    }
    
    func startScreenShare(videoSource: RTCVideoSource, videoCapture: RTCVideoCapturer) {
        let screenSharefactory = RTCPeerConnectionFactory()
        RPScreenRecorder.shared().startCapture(handler: { [weak self] (cmSampleBuffer, rpSampleType, error) in
            switch rpSampleType {
            case RPSampleBufferType.video:
                // create the CVPixelBuffer
                guard let pixelBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(cmSampleBuffer) else {
                    break
                }
                let rtcpixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
                let timeStampNs: Int64 = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer)) * 1000000000)
                let videoFrame = RTCVideoFrame(buffer: rtcpixelBuffer, rotation: RTCVideoRotation._0, timeStampNs: timeStampNs)
               
                videoSource.capturer(videoCapture, didCapture: videoFrame)
            case RPSampleBufferType.audioApp:
                break
            case RPSampleBufferType.audioMic:
                break
            default:
                print("sample has no matching type")
            }
        })
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        if peerConnection == self.screenSharePeerConnection {
            debugPrint("screen share peerConnection new signaling state: \(stateChanged)")
        } else {
            debugPrint("peerConnection new signaling state: \(stateChanged)")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if peerConnection == self.screenSharePeerConnection {
            debugPrint("screen share peerConnection did add stream")
        } else {
            debugPrint("peerConnection did add stream")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        if peerConnection == self.screenSharePeerConnection {
            debugPrint("screen share peerConnection did remove stream")
        } else {
            debugPrint("peerConnection did remove stream")
        }
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        if peerConnection == self.screenSharePeerConnection {
            debugPrint("screen share peerConnection should negotiate")
        } else {
            debugPrint("peerConnection should negotiate")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        if peerConnection == self.screenSharePeerConnection {
            self.delegate?.webRTCClient(self, didChangeConnectionState: newState, peerConnectionType:   .screenShare)
        } else {
            self.delegate?.webRTCClient(self, didChangeConnectionState: newState, peerConnectionType:   .main)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        if peerConnection == self.screenSharePeerConnection {
            debugPrint("Screen share peerConnection new gathering state: \(newState)")
        } else {
            debugPrint("peerConnection new gathering state: \(newState)")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        if peerConnection == self.screenSharePeerConnection {
            self.delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate, peerConnectionType: .screenShare)
        } else {
            self.delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate, peerConnectionType: .main)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        if peerConnection == self.screenSharePeerConnection {
            debugPrint("screen share peerConnection did remove candidate(s)")
        } else {
            debugPrint("peerConnection did remove candidate(s)")
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        if peerConnection == self.screenSharePeerConnection {
            debugPrint("screen share peerConnection did open data channel")
        } else {
            debugPrint("peerConnection did open data channel")
            self.remoteDataChannel = dataChannel
        }
    }
}
extension WebRTCClient {
    private func setTrackEnabled<T: RTCMediaStreamTrack>(_ type: T.Type, isEnabled: Bool) {
        peerConnection.transceivers
            .compactMap { return $0.sender.track as? T }
            .forEach { $0.isEnabled = isEnabled }
    }
}

// MARK: - Video control
extension WebRTCClient {
    func hideVideo() {
        self.setVideoEnabled(false)
    }
    func showVideo() {
        self.setVideoEnabled(true)
    }
    private func setVideoEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCVideoTrack.self, isEnabled: isEnabled)
    }
}
// MARK:- Audio control
extension WebRTCClient {
    func muteAudio() {
        self.setAudioEnabled(false)
    }
    
    func unmuteAudio() {
        self.setAudioEnabled(true)
    }
    
    // Fallback to the default playing device: headphones/bluetooth/ear speaker
    func speakerOff() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.none)
            } catch let error {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }
    
    // Force speaker
    func speakerOn() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
                try self.rtcAudioSession.setActive(true)
            } catch let error {
                debugPrint("Couldn't force audio to speaker: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }
    
    private func setAudioEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCAudioTrack.self, isEnabled: isEnabled)
    }
}

extension WebRTCClient: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        debugPrint("dataChannel did change state: \(dataChannel.readyState)")
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        self.delegate?.webRTCClient(self, didReceiveData: buffer.data)
    }
}


extension String {

    static func random(length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""

        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
    }
}
