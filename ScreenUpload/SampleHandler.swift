//
//  SampleHandler.swift
//  ScreenUpload
//
//  Created by Tran Ngoc Tam on 10/13/20.
//  Copyright © 2020 Tran Ngoc Tam. All rights reserved.
//

import ReplayKit
import WebRTC

class SampleHandler: RPBroadcastSampleHandler {
    
    private let config = Config.default
    private let signalClient: SignalingClient
    private let webRTCClient: WebRTCClient
    
    override init() {
        
        webRTCClient = WebRTCClient(iceServers: self.config.webRTCIceServers)
        
        // iOS 13 has native websocket support. For iOS 12 or lower we will use 3rd party library.
        let webSocketProvider: WebSocketProvider
        
      
        webSocketProvider = NativeWebSocket(url: self.config.signalingServerUrl)
        signalClient = SignalingClient(webSocket: webSocketProvider)
        
        super.init()
        
        self.webRTCClient.delegate = self
        self.signalClient.delegate = self
        signalClient.connect()
        print("connect")
    }
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        print("broadcastStarted")
        
            let constrains = RTCMediaConstraints(mandatoryConstraints: webRTCClient.screenShareMediaConstrains,
            optionalConstraints: nil)
            webRTCClient.screenSharePeerConnection.offer(for: constrains) { (sdp, error) in
                guard let sdp = sdp else {
                    return
                }
                print("offer")
                self.webRTCClient.screenSharePeerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                    self.signalClient.send(sdp: sdp, peerConnectionType: .screenShare)
                })
            }
        
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
    }
    
    deinit {
        
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            guard let videoSource = webRTCClient.videoSource, let capturer = webRTCClient.videoCapturer, let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                break
            }
            
            let timeStampNs: Int64 = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000000000)
            let rtcPixlBuffer = RTCCVPixelBuffer(pixelBuffer: imageBuffer)
            let rtcVideoFrame = RTCVideoFrame(buffer: rtcPixlBuffer, rotation: ._0, timeStampNs: timeStampNs)

            videoSource.capturer(capturer, didCapture: rtcVideoFrame)
            break
        case RPSampleBufferType.audioApp:
            // Handle audio sample buffer for app audio
            break
        case RPSampleBufferType.audioMic:
            // Handle audio sample buffer for mic audio
            break
        @unknown default:
            // Handle other sample buffer types
            fatalError("Unknown type of sample buffer")
        }
    }
}

extension SampleHandler: SignalClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription, peerConnectionType: PeerConnectionType, mainPeerLocalSdp: String?, mainPeerRemoteSdp: String?) {
        self.webRTCClient.set(remoteSdp: sdp, peerConnectionType: peerConnectionType) { (error) in
            
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate, peerConnectionType: PeerConnectionType) {
        self.webRTCClient.set(remoteCandidate: candidate, peerConnectionType: peerConnectionType)
    }
    
    
}

extension SampleHandler: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate, peerConnectionType: PeerConnectionType) {
        self.signalClient.send(candidate: candidate, peerConnectionType: peerConnectionType)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState, peerConnectionType: PeerConnectionType) {
        
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        
    }
}
