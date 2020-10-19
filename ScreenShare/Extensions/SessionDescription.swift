//
//  SessionDescription.swift
//  ScreenShare
//
//  Created by Tran Ngoc Tam on 10/9/20.
//  Copyright © 2020 Tran Ngoc Tam. All rights reserved.
//

import Foundation
import WebRTC

/// This enum is a swift wrapper over `RTCSdpType` for easy encode and decode
enum SdpType: String, Codable {
    case offer, prAnswer, answer
    
    var rtcSdpType: RTCSdpType {
        switch self {
        case .offer:    return .offer
        case .answer:   return .answer
        case .prAnswer: return .prAnswer
        }
    }
}

enum PeerConnectionType: String, Codable {
    case main, screenShare
}

/// This struct is a swift wrapper over `RTCSessionDescription` for easy encode and decode
struct SessionDescription: Codable {
    let sdp: String
    let type: SdpType
    let peerConnectionType: PeerConnectionType
    
    // For Screen share, to check main peer connection is already or not
    var mainPeerLocalSdp: String?
    var mainPeerRemoteSdp: String?
    
    init(from rtcSessionDescription: RTCSessionDescription, peerConnectionType: PeerConnectionType) {
        self.sdp = rtcSessionDescription.sdp
        self.peerConnectionType = peerConnectionType
        
        // send to compare main peer is already connecting
        if peerConnectionType == .screenShare {
            mainPeerLocalSdp = AppGroupUserDefault.shared.getLocalSdpString()
            mainPeerRemoteSdp = AppGroupUserDefault.shared.getRemoteSdp()
        }
        
        switch rtcSessionDescription.type {
        case .offer:    self.type = .offer
        case .prAnswer: self.type = .prAnswer
        case .answer:   self.type = .answer
        @unknown default:
            fatalError("Unknown RTCSessionDescription type: \(rtcSessionDescription.type.rawValue)")
        }
    }
    
    var rtcSessionDescription: RTCSessionDescription {
        return RTCSessionDescription(type: self.type.rtcSdpType, sdp: self.sdp)
    }
}
