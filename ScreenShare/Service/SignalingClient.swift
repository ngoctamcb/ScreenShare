//
//  SignalingClient.swift
//  ScreenShare
//
//  Created by Tran Ngoc Tam on 10/9/20.
//  Copyright © 2020 Tran Ngoc Tam. All rights reserved.
//

import Foundation
import WebRTC

protocol SignalClientDelegate: class {
    func signalClientDidConnect(_ signalClient: SignalingClient)
    func signalClientDidDisconnect(_ signalClient: SignalingClient)
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription, peerConnectionType: PeerConnectionType, mainPeerLocalSdp: String?, mainPeerRemoteSdp: String?)
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate, peerConnectionType: PeerConnectionType)
}

final class SignalingClient {
    
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let webSocket: WebSocketProvider
    weak var delegate: SignalClientDelegate?
    
    init(webSocket: WebSocketProvider) {
        self.webSocket = webSocket
    }
    
    func connect() {
        self.webSocket.delegate = self
        self.webSocket.connect()
    }
    
    func send(sdp rtcSdp: RTCSessionDescription, peerConnectionType: PeerConnectionType) {
        let message = Message.sdp(SessionDescription(from: rtcSdp, peerConnectionType: peerConnectionType))
        do {
            let dataMessage = try self.encoder.encode(message)
            
            self.webSocket.send(data: dataMessage)
        }
        catch {
            debugPrint("Warning: Could not encode sdp: \(error)")
        }
    }
    
    func send(candidate rtcIceCandidate: RTCIceCandidate, peerConnectionType: PeerConnectionType) {
        let message = Message.candidate(IceCandidate(from: rtcIceCandidate, peerConnectionType: peerConnectionType))
        do {
            let dataMessage = try self.encoder.encode(message)
            self.webSocket.send(data: dataMessage)
        }
        catch {
            debugPrint("Warning: Could not encode candidate: \(error)")
        }
    }
}


extension SignalingClient: WebSocketProviderDelegate {
    func webSocketDidConnect(_ webSocket: WebSocketProvider) {
            self.delegate?.signalClientDidConnect(self)
        }
        
        func webSocketDidDisconnect(_ webSocket: WebSocketProvider) {
            self.delegate?.signalClientDidDisconnect(self)
            
            // try to reconnect every two seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                debugPrint("Trying to reconnect to signaling server...")
                self.webSocket.connect()
            }
        }
        
        func webSocket(_ webSocket: WebSocketProvider, didReceiveData data: Data) {
            let message: Message
            do {
                message = try self.decoder.decode(Message.self, from: data)
            }
            catch {
                debugPrint("Warning: Could not decode incoming message: \(error)")
                return
            }
            
            switch message {
            case .candidate(let iceCandidate):
                self.delegate?.signalClient(self, didReceiveCandidate: iceCandidate.rtcIceCandidate, peerConnectionType: iceCandidate.peerConnectionType)
            case .sdp(let sessionDescription):
    //            self.delegate?.signalClient(self, didReceiveRemoteSdp: sessionDescription.rtcSessionDescription, peerConnectionType: sessionDescription.peerConnectionType)
                self.delegate?.signalClient(self, didReceiveRemoteSdp: sessionDescription.rtcSessionDescription, peerConnectionType: sessionDescription.peerConnectionType, mainPeerLocalSdp: sessionDescription.mainPeerLocalSdp, mainPeerRemoteSdp: sessionDescription.mainPeerRemoteSdp)
            }
        }
}
