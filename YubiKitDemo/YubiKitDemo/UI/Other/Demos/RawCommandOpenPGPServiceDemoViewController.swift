// Copyright 2018-2019 Yubico AB
// Copyright 2021 Matt Beshara
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit

class RawCommandOpenPGPServiceDemoViewController: OtherDemoRootViewController {

    private enum ViewControllerKeyType {
        case none
        case accessory
        case nfc
    }

    private let swCodeSuccess: UInt16 = 0x9000
    private var keyType: ViewControllerKeyType = .none

    // MARK: - Outlets

    @IBOutlet var logTextView: UITextView!
    @IBOutlet var runDemoButton: UIButton!

    // MARK: - Actions
    @IBAction func runDemoButtonPressed(_ sender: Any) {
        YubiKitExternalLocalization.nfcScanAlertMessage = "Insert YubiKey or scan over the top edge of your iPhone";
        let keyConnected = YubiKitManager.shared.accessorySession.sessionState == .open

        if YubiKitDeviceCapabilities.supportsISO7816NFCTags && !keyConnected {
            guard #available(iOS 13.0, *) else {
                fatalError()
            }
            YubiKitManager.shared.nfcSession.startIso7816Session()
        } else {
            keyType = .accessory

            logTextView.text = nil
            setDemoButton(enabled: false)

            DispatchQueue.global(qos: .default).async { [weak self] in
                guard let self = self else {
                    return
                }
                self.runOpenPGPDemo(keyService: YubiKitManager.shared.accessorySession.rawCommandService)
                self.setDemoButton(enabled: true)
            }
        }
    }

    private func setDemoButton(enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.runDemoButton.isEnabled = enabled
            self.runDemoButton.backgroundColor = enabled ? NamedColor.yubicoGreenColor : UIColor.lightGray
        }
    }

    // MARK: - Raw Command Service Example

    private func runOpenPGPDemo(keyService: YKFKeyRawCommandServiceProtocol?) {
        let keyPluggedIn = YubiKitManager.shared.accessorySession.sessionState == .open
        if keyPluggedIn {
            let serialNumber = YubiKitManager.shared.accessorySession.accessoryDescription!.serialNumber
            log(message: "The key serial number is: \(serialNumber).")
        }

        guard let keyService = keyService else {
            log(message: "The key is not connected")
            return
        }

        let selectOpenPGPCommand = Data([0x00, 0xA4, 0x04, 0x00, 0x06, 0xD2, 0x76, 0x00, 0x01, 0x24, 0x01])
        guard let selectOpenPGPApdu = YKFAPDU(data: selectOpenPGPCommand) else {
            return
        }

        keyService.executeSyncCommand(selectOpenPGPApdu, completion: { [weak self] (response, error) in
            guard let self = self else {
                return
            }
            guard error == nil else {
                self.log(message: "Error when executing command: \(error!.localizedDescription)")
                return
            }

            let responseParser = RawDemoResponseParser(response: response!)
            let statusCode = responseParser.statusCode

            if statusCode == self.swCodeSuccess {
                self.log(message: "OpenPGP application selected.")
            } else {
                self.log(message: "OpenPGP application selection failed. SW returned by the key: \(statusCode).")
            }
        })


        let getOpenPGPURLCommand = Data([0x00, 0xCA, 0x5F, 0x50, 0x00])
        guard let getOpenPGPURLApdu = YKFAPDU(data: getOpenPGPURLCommand) else {
            return
        }

        keyService.executeSyncCommand(getOpenPGPURLApdu, completion: { [weak self] (response, error) in
            guard let self = self else {
                return
            }
            guard error == nil else {
                self.log(message: "Error when executing command: \(error!.localizedDescription)")
                return
            }

            let responseParser = RawDemoResponseParser(response: response!)
            let statusCode = responseParser.statusCode

            if statusCode == self.swCodeSuccess,
               let data = responseParser.responseData,
               let url = String(data: data, encoding: .utf8) {
                self.log(message: "Got URL: \(url)")
            } else {
                self.log(message: "Failed to get URL. SW returned by the key: \(statusCode).")
            }
        })
    }

    // MARK: - Session State Updates

    override func accessorySessionStateDidChange() {
        switch YubiKitManager.shared.accessorySession.sessionState {
        case .closed:
            logTextView.text = nil
            setDemoButton(enabled: true)
        case .open:
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
                guard #available(iOS 13.0, *) else {
                    fatalError()
                }

                DispatchQueue.global(qos: .default).async { [weak self] in
                    // if NFC UI is visible we consider the button is pressed
                    // and we run demo as soon as 5ci connected
                    if (YubiKitManager.shared.nfcSession.iso7816SessionState != .closed) {
                        guard let self = self else {
                            return
                        }
                        YubiKitManager.shared.nfcSession.stopIso7816Session()
                        self.runOpenPGPDemo(keyService: YubiKitManager.shared.accessorySession.rawCommandService)
                    }
                }
            }
        default:
            break
        }
    }

    @available(iOS 13.0, *)
    override func nfcSessionStateDidChange() {
        // Execute the request after the key(tag) is connected.
        switch YubiKitManager.shared.nfcSession.iso7816SessionState {
        case .open:
            DispatchQueue.global(qos: .default).async { [weak self] in
                guard let self = self else {
                    return
                }

                // NOTE: session can be closed during the execution of demo on background thread,
                // so we need to make sure that we handle case when rawCommandService for nfcSession is nil
                self.runOpenPGPDemo(keyService: YubiKitManager.shared.nfcSession.rawCommandService)
                // Stop the session to dismiss the Core NFC system UI.
                YubiKitManager.shared.nfcSession.stopIso7816Session()
            }
        default:
            break
        }
    }

    // MARK: - Logging Helpers

    private func log(message: String) {
        DispatchQueue.main.async { [weak self] in
            print(message)
            self?.logTextView.insertText("\(message)\n")
        }
    }
}
