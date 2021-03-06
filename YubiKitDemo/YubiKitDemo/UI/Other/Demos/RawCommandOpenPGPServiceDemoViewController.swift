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

class RawCommandOpenPGPServiceDemoViewController: OtherDemoRootViewController, UITextFieldDelegate {

    private enum ViewControllerKeyType {
        case none
        case accessory
        case nfc
    }

    private let swCodeSuccess: UInt16 = 0x9000
    private var keyType: ViewControllerKeyType = .none
    private var pin: String?

    // This ciphertext/expected plaintext pair are only valid for my keypair.
    // You will need to update them with values valid for a keypair you have
    // for the result of the deciphering to equal the expected plaintext.
    private let ecdhCiphertextBytes: [UInt8] =
        [0x39, 0x89, 0x48, 0x9E, 0x0E, 0x82, 0x1B, 0xB8, 0xF7, 0x34, 0x8C, 0xE0, 0x62, 0x55, 0x27, 0x0A, 0xAE, 0xD2, 0x50, 0xA7, 0x35, 0x9D, 0x18, 0x20, 0x02, 0xAF, 0x0E, 0x4F, 0xDF, 0x11, 0x69, 0x6C]
    private let plaintextBytes: [UInt8] = [0xA7, 0xA5, 0xC8, 0xF2, 0xCC, 0x5B, 0xDB, 0xC0, 0x1E, 0x44, 0xFC, 0xB5, 0xAA, 0x61, 0x5F, 0x28, 0x35, 0x31, 0xA8, 0x7B, 0x29, 0xF0, 0xA5, 0x0B, 0x57, 0xDD, 0x08, 0x30, 0x97, 0x33, 0xE3, 0x29]

    // MARK: - Outlets

    @IBOutlet var logTextView: UITextView!
    @IBOutlet var runDemoButton: UIButton!

    // MARK: - Actions
    @IBAction func runDemoButtonPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Enter PIN", message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.enablesReturnKeyAutomatically = true
            $0.keyboardType = .asciiCapable
            $0.returnKeyType = .done
            $0.smartDashesType = .no
            $0.smartInsertDeleteType = .no
            $0.smartQuotesType = .no

            $0.delegate = self
        }
        present(alert, animated: true, completion: nil)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        pin = textField.text
        runDemo()
        presentedViewController?.dismiss(animated: true, completion: nil)
        return true
    }

    private func runDemo() {
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
        guard let pinData = pin?.data(using: .utf8) else {
            log(message: "No PIN specified")
            return
        }

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


        let getURLCommand = Data([0x00, 0xCA, 0x5F, 0x50, 0x00])
        guard let getURLApdu = YKFAPDU(data: getURLCommand) else {
            return
        }

        keyService.executeSyncCommand(getURLApdu, completion: { [weak self] (response, error) in
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


        var verifyDecipherPINCommand = Data([0x00, 0x20, 0x00, 0x82])
        verifyDecipherPINCommand.append(UInt8(pinData.count))
        verifyDecipherPINCommand.append(pinData)
        guard let verifyDecipherPINApdu = YKFAPDU(data: verifyDecipherPINCommand) else {
            return
        }

        keyService.executeSyncCommand(verifyDecipherPINApdu, completion: { [weak self] (response, error) in
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
                let formattedData = Data(self.ecdhCiphertextBytes).base64EncodedString()
                self.log(message: "PIN correct, deciphering ciphertext: \(formattedData)")
            } else {
                self.log(message: "Failed to verify PIN was correct. SW returned by the key: \(statusCode).")
            }
        })


        var decipherECDHCiphertextCommand = Data([0x00, 0x2A, 0x80, 0x86, 0x27, 0xa6, 0x25, 0x7f, 0x49, 0x22, 0x86])
        decipherECDHCiphertextCommand.append(UInt8(ecdhCiphertextBytes.count))
        decipherECDHCiphertextCommand.append(contentsOf: ecdhCiphertextBytes)
        guard let decipherECDHCiphertextApdu = YKFAPDU(data: decipherECDHCiphertextCommand) else {
            return
        }

        keyService.executeSyncCommand(decipherECDHCiphertextApdu, completion: { [weak self] (response, error) in
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
                self.log(message: "Decipher successful, comparing with expected plaintext…")
                let formattedData = responseParser.responseData?.base64EncodedString() ?? "<responseData was nil>"
                if responseParser.responseData == Data(self.plaintextBytes) {
                    self.log(message: "Got expected plaintext: \(formattedData)")
                } else {
                    self.log(message: "Got unexpected plaintext: \(formattedData)")
                }
            } else {
                self.log(message: "Failed to decipher. SW returned by the key: \(statusCode).")
            }
        })

        var verifySignPINCommand = Data([0x00, 0x20, 0x00, 0x81])
        verifySignPINCommand.append(UInt8(pinData.count))
        verifySignPINCommand.append(pinData)
        guard let verifySignPINApdu = YKFAPDU(data: verifySignPINCommand) else {
            return
        }

        keyService.executeSyncCommand(verifySignPINApdu, completion: { [weak self] (response, error) in
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
                self.log(message: "PIN correct, signing ciphertext…")
            } else {
                self.log(message: "Failed to verify PIN was correct. SW returned by the key: \(statusCode).")
            }
        })

        var signCiphertextCommand = Data([0x00, 0x2A, 0x9E, 0x9A])
        signCiphertextCommand.append(UInt8(ecdhCiphertextBytes.count))
        signCiphertextCommand.append(contentsOf: ecdhCiphertextBytes)
        guard let signCiphertextApdu = YKFAPDU(data: signCiphertextCommand) else {
            return
        }

        keyService.executeSyncCommand(signCiphertextApdu, completion: { [weak self] (response, error) in
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
                let formattedData = responseParser.responseData?.base64EncodedString() ?? "<responseData was nil>"
                self.log(message: "Signing successful, got signature data: \(formattedData)")
            } else {
                self.log(message: "Failed to sign. SW returned by the key: \(statusCode).")
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
