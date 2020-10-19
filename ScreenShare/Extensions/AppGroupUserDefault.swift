//
//  AppGroupUserDefault.swift
//  ScreenShare
//
//  Created by Tran Ngoc Tam on 10/19/20.
//  Copyright © 2020 Tran Ngoc Tam. All rights reserved.
//

import Foundation

class AppGroupUserDefault {
    static let shared = AppGroupUserDefault()

    let defaults = UserDefaults(suiteName: "group.com.screenshare")
    let kLocalSdp: String = "key.localsdp"
    let kRemoteSdp = "key.remotesdp"
    
    func storeLocalSdpString(sdp: String) {
        defaults?.set(sdp, forKey: kLocalSdp)
    }
    
    func getLocalSdpString() -> String? {
        let sdpString = defaults?.string(forKey: kLocalSdp)
        return sdpString
    }
    
    func storeRemoteSdp(sdp: String) {
        defaults?.set(sdp, forKey: kRemoteSdp)
    }
    
    func getRemoteSdp() -> String? {
        let sdpString = defaults?.string(forKey: kRemoteSdp)
        return sdpString
    }
    
    func clearAll() {
        defaults?.removeObject(forKey: kLocalSdp)
        defaults?.removeObject(forKey: kRemoteSdp)
    }
}
