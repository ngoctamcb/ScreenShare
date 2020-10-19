//
//  IceCandidate.swift
//  ScreenShare
//
//  Created by Tran Ngoc Tam on 10/9/20.
//  Copyright © 2020 Tran Ngoc Tam. All rights reserved.
//

import Foundation
import WebRTC

/// This struct is a swift wrapper over `RTCIceCandidate` for easy encode and decode
struct IceCandidate: Codable {
    let sdp: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
    let peerConnectionType: PeerConnectionType
    
    init(from iceCandidate: RTCIceCandidate, peerConnectionType: PeerConnectionType) {
        self.sdpMLineIndex = iceCandidate.sdpMLineIndex
        self.sdpMid = iceCandidate.sdpMid
        self.sdp = iceCandidate.sdp
        self.peerConnectionType = peerConnectionType
    }
    
    var rtcIceCandidate: RTCIceCandidate {
        return RTCIceCandidate(sdp: self.sdp, sdpMLineIndex: self.sdpMLineIndex, sdpMid: self.sdpMid)
    }
}
