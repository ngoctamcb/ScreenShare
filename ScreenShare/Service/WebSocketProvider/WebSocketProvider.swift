//
//  WebSocketProvider.swift
//  ScreenShare
//
//  Created by Tran Ngoc Tam on 10/9/20.
//  Copyright © 2020 Tran Ngoc Tam. All rights reserved.
//

import Foundation

protocol WebSocketProvider: class {
    var delegate: WebSocketProviderDelegate? { get set }
    func connect()
    func send(data: Data)
}

protocol WebSocketProviderDelegate: class {
    func webSocketDidConnect(_ webSocket: WebSocketProvider)
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider)
    func webSocket(_ webSocket: WebSocketProvider, didReceiveData data: Data)
}
