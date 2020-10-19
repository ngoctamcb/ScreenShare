//
//  MainViewController.swift
//  ScreenShare
//
//  Created by Tran Ngoc Tam on 10/12/20.
//  Copyright © 2020 Tran Ngoc Tam. All rights reserved.
//

import UIKit
import AVFoundation
import WebRTC
import Foundation
import ReplayKit

class MainViewController: UIViewController {

    private let signalClient: SignalingClient
    private let webRTCClient: WebRTCClient
    private lazy var videoViewController = VideoViewController(webRTCClient: self.webRTCClient)
    
    @IBOutlet private weak var speakerButton: UIButton?
    @IBOutlet private weak var signalingStatusLabel: UILabel?
    @IBOutlet private weak var localSdpStatusLabel: UILabel?
    @IBOutlet private weak var localCandidatesLabel: UILabel?
    @IBOutlet private weak var remoteSdpStatusLabel: UILabel?
    @IBOutlet private weak var remoteCandidatesLabel: UILabel?
    @IBOutlet private weak var muteButton: UIButton?
    @IBOutlet private weak var webRTCStatusLabel: UILabel?
    @IBOutlet weak var screenShareStatusLabel: UILabel!
    
    private var signalingConnected: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.signalingConnected {
                    self.signalingStatusLabel?.text = "Connected"
                    self.signalingStatusLabel?.textColor = UIColor.green
                }
                else {
                    self.signalingStatusLabel?.text = "Not connected"
                    self.signalingStatusLabel?.textColor = UIColor.red
                }
            }
        }
    }
    
    private var hasLocalSdp: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.localSdpStatusLabel?.text = self.hasLocalSdp ? "✅" : "❌"
            }
        }
    }
    
    private var localCandidateCount: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.localCandidatesLabel?.text = "\(self.localCandidateCount)"
            }
        }
    }
    
    private var hasRemoteSdp: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.remoteSdpStatusLabel?.text = self.hasRemoteSdp ? "✅" : "❌"
            }
        }
    }
    
    private var remoteCandidateCount: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.remoteCandidatesLabel?.text = "\(self.remoteCandidateCount)"
            }
        }
    }
    
    private var speakerOn: Bool = false {
        didSet {
            let title = "Speaker: \(self.speakerOn ? "On" : "Off" )"
            self.speakerButton?.setTitle(title, for: .normal)
        }
    }
    
    private var mute: Bool = false {
        didSet {
            let title = "Mute: \(self.mute ? "on" : "off")"
            self.muteButton?.setTitle(title, for: .normal)
        }
    }
    
    init(signalClient: SignalingClient, webRTCClient: WebRTCClient) {
        self.signalClient = signalClient
        self.webRTCClient = webRTCClient
        super.init(nibName: String(describing: MainViewController.self), bundle: Bundle.main)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "WebRTC Demo"
        self.signalingConnected = false
        self.hasLocalSdp = false
        self.hasRemoteSdp = false
        self.localCandidateCount = 0
        self.remoteCandidateCount = 0
        self.speakerOn = false
        self.webRTCStatusLabel?.text = "New"
        
        self.webRTCClient.delegate = self
        self.signalClient.delegate = self
        self.signalClient.connect()
        
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 200, width: 80, height: 80))
        pickerView.preferredExtension = "com.ltanh.webrtc.BroadcastUploadExtension"
        self.view.addSubview(pickerView)
    }
    
    @IBAction private func offerDidTap(_ sender: UIButton) {
        self.webRTCClient.offer { (sdp) in
            self.hasLocalSdp = true
            self.signalClient.send(sdp: sdp, peerConnectionType: .main)
        }
    }
    
    @IBAction private func answerDidTap(_ sender: UIButton) {
         self.webRTCClient.answer { (localSdp) in
            self.hasLocalSdp = true
            self.signalClient.send(sdp: localSdp, peerConnectionType: .main)
        }
    }
    
    @IBAction private func speakerDidTap(_ sender: UIButton) {
        if self.speakerOn {
            self.webRTCClient.speakerOff()
        }
        else {
            self.webRTCClient.speakerOn()
        }
        self.speakerOn = !self.speakerOn
    }
    
    @IBAction private func videoDidTap(_ sender: UIButton) {
        self.present(videoViewController, animated: true, completion: nil)
    }
    
    @IBAction private func muteDidTap(_ sender: UIButton) {
        self.mute = !self.mute
        if self.mute {
            self.webRTCClient.muteAudio()
        }
        else {
            self.webRTCClient.unmuteAudio()
        }
    }
    
    @IBAction func sendDataDidTap(_ sender: UIButton) {
        let alert = UIAlertController(title: "Send a message to the other peer",
                                      message: "This will be transferred over WebRTC data channel",
                                      preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Message to send"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { [weak self, unowned alert] _ in
            guard let dataToSend = alert.textFields?.first?.text?.data(using: .utf8) else {
                return
            }
            self?.webRTCClient.sendData(dataToSend)
        }))
        self.present(alert, animated: true, completion: nil)
    }
}

extension MainViewController: SignalClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        self.signalingConnected = true
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        self.signalingConnected = false
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription, peerConnectionType: PeerConnectionType, mainPeerLocalSdp: String?, mainPeerRemoteSdp: String?) {
        print("Received remote sdp")
        self.webRTCClient.set(remoteSdp: sdp, peerConnectionType: peerConnectionType) { (error) in
            self.hasRemoteSdp = true
        }
        
        // If screen share, check main peer is already have, if have answer automatically
        if peerConnectionType == .screenShare, let mainPeerLocalSdp = mainPeerLocalSdp, let mainPeerRemoteSdp = mainPeerRemoteSdp {
            if (mainPeerLocalSdp.components(separatedBy: "\n")[1] == webRTCClient.peerConnection.remoteDescription?.sdp.components(separatedBy: "\n")[1] && mainPeerRemoteSdp.components(separatedBy: "\n")[1] == webRTCClient.peerConnection.localDescription?.sdp.components(separatedBy: "\n")[1] && sdp.type == .offer) {

                let constrains = RTCMediaConstraints(mandatoryConstraints: webRTCClient.screenShareMediaConstrains,
                optionalConstraints: nil)
                print("answer answer")
                webRTCClient.screenSharePeerConnection.answer(for: constrains) { (sdp, error) in
                    guard let sdp = sdp else {
                        return
                    }

                    self.webRTCClient.screenSharePeerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                        self.signalClient.send(sdp: sdp, peerConnectionType: .screenShare)
                    })
                }
            }
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate, peerConnectionType: PeerConnectionType) {
        print("Received remote candidate")
        self.remoteCandidateCount += 1
        self.webRTCClient.set(remoteCandidate: candidate, peerConnectionType: peerConnectionType)
    }
}

extension MainViewController: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate, peerConnectionType: PeerConnectionType) {
        print("discovered local candidate")
        self.localCandidateCount += 1
        self.signalClient.send(candidate: candidate, peerConnectionType: peerConnectionType)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState, peerConnectionType: PeerConnectionType) {
        switch peerConnectionType {
        case .main:
            let textColor: UIColor
            switch state {
            case .connected, .completed:
                textColor = .green
            case .disconnected:
                textColor = .orange
            case .failed, .closed:
                textColor = .red
            case .new, .checking, .count:
                textColor = .black
            @unknown default:
                textColor = .black
            }
            DispatchQueue.main.async {
                self.webRTCStatusLabel?.text = state.description.capitalized
                self.webRTCStatusLabel?.textColor = textColor
            }
        case .screenShare:
            let textColor: UIColor
            switch state {
            case .connected, .completed:
                textColor = .green
            case .disconnected:
                textColor = .orange
            case .failed, .closed:
                textColor = .red
            case .new, .checking, .count:
                textColor = .black
            @unknown default:
                textColor = .black
            }
            DispatchQueue.main.async {
                self.screenShareStatusLabel?.text = state.description.capitalized
                self.screenShareStatusLabel?.textColor = textColor
            }
        }
        
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        DispatchQueue.main.async {
            let message = String(data: data, encoding: .utf8) ?? "(Binary: \(data.count) bytes)"
            let alert = UIAlertController(title: "Message from WebRTC", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

