//
//  PMChallenge.swift
//  ProtonCore-Challenge - Created on 6/19/20.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import UIKit
import Foundation
import ProtonCore_Foundations

public final class PMChallenge: ChallengeProtocol {
    private static let queue = DispatchQueue(label: "com.protonmail.challenge")
    private static var shareInstance: PMChallenge?
    /// Collected challenge data
    private var challenge = PMChallenge.Challenge()
    /// Interceptor of `UITextField`
    private var interceptors: [TextFieldDelegateInterceptor] = []
    /// To calculate number of second that user editing username
    private var usernameEditingTime: TimeInterval = 0
    /// To calculate number of second that user editing recovery
    private var recoveryEditingTime: TimeInterval = 0
    /// Copy event debounce
    private var copyDebounce: TimeInterval = 0

    public init() {
        self.subscribeNotification()
    }

    deinit {
        self.unsubscribeNotification()
        self.reset()
    }

    /// Get shared instance, thread safe
    public static func shared() -> PMChallenge {
        queue.sync {
            if let shareInstance = PMChallenge.shareInstance {
                shareInstance.subscribeNotification()
                return shareInstance
            }
            PMChallenge.shareInstance = PMChallenge()
            return PMChallenge.shareInstance!
        }
    }

    /// Release shared instance
    public static func release() {
        queue.sync {
            PMChallenge.shareInstance?.unsubscribeNotification()
            PMChallenge.shareInstance?.reset()
            PMChallenge.shareInstance = nil
        }
    }
}

// MARK: Public function
extension PMChallenge {
    /// Reset collected data, should called this function before collect data
    public func reset() {
        self.challenge.reset()

        self.interceptors.forEach({ $0.destroy() })
        self.interceptors = []
        self.usernameEditingTime = 0
    }

    /// Export collected challenge data
    public func export() -> PMChallenge.Challenge {
        let semaphore = DispatchSemaphore(value: 0)
        runInMainThread {
            self.challenge.fetchValues()
            semaphore.signal()
        }
        semaphore.wait()
        let challenge = self.challenge
        self.challenge.reset()
        return challenge
    }

    /**
     Start to observe given textfield
     
     If you call this function with the same type (or same textField) twice.
     The data of the first called will be overridden by the second called.
     
     - Parameter textField: textField will be observe
     - Parameter type: The usage of this textField
     - Parameter ignoreDelegate: Should ignore textField delegate missing error?
     */
    public func observeTextField(_ textField: UITextField, type: TextFieldType, ignoreDelegate: Bool = false) throws {

        while true {
            if let idx = self.interceptors.firstIndex(where: { $0.type == type || $0.textField == textField }) {
                let interceptor = self.interceptors.remove(at: idx)
                interceptor.destroy()
            } else {
                break
            }
        }

        do {
            let interceptor = try TextFieldDelegateInterceptor(textField: textField,
                                                               type: type, delegate: self,
                                                               ignoreDelegate: ignoreDelegate)
            self.interceptors.append(interceptor)
        } catch {
            throw error
        }

        switch type {
        case .username, .username_email:
            self.usernameEditingTime = 0
            self.challenge.timeUsername = []
        case .recoveryMail, .recoveryPhone:
            self.recoveryEditingTime = 0
        default:
            break
        }
    }

    /// Record username that checks availability
    public func appendCheckedUsername(_ username: String) {
        guard let interceptor = self.interceptors.first(where: { $0.type == .username }) else {
            return
        }
        // make sure the textField is not focused after check username.
        interceptor.textField?.resignFirstResponder()
    }
}

// MARK: Private function
extension PMChallenge {
    private func runInMainThread(closure: @escaping () -> Void) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async {
                closure()
            }
        }
    }
}

// MARK: Notification
extension PMChallenge {
    private func subscribeNotification() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(PMChallenge.copyEvent),
                                               name: UIPasteboard.changedNotification,
                                               object: nil)
    }

    private func unsubscribeNotification() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func copyEvent() {
        guard let interceptor = self.interceptors.first(where: { $0.textField?.isFirstResponder ?? false }) else {
            return
        }

        let now = Date().timeIntervalSince1970
        if now - self.copyDebounce < 1 {
            return
        }
        self.copyDebounce = now

        guard let copyText = UIPasteboard.general.string else { return }
        switch interceptor.type {
        case .username, .username_email:
            self.challenge.copyUsername.append(copyText)
            self.challenge.keydownUsername.append("Copy")
        case .recoveryMail, .recoveryPhone:
            self.challenge.copyRecovery.append(copyText)
            self.challenge.keydownRecovery.append("Copy")
        default:
            break
        }
    }
}

// MARK: TextFieldInterceptorDelegate, internal usage
extension PMChallenge: TextFieldInterceptorDelegate {
    func beginEditing(type: TextFieldType) {
        switch type {
        case .username, .username_email:
            if self.usernameEditingTime == 0 {
                self.usernameEditingTime = Date().timeIntervalSince1970
            }
        case .recoveryPhone, .recoveryMail:
            self.recoveryEditingTime = Date().timeIntervalSince1970
        default:
            break
        }
    }

    func endEditing(type: TextFieldType) {
        switch type {
        case .recoveryMail, .recoveryPhone:
            let diff = Int(Date().timeIntervalSince1970 - self.recoveryEditingTime)
            guard self.recoveryEditingTime > 0,
                  diff > 0 else { return }
            self.challenge.timeRecovery.append(diff)
            self.recoveryEditingTime = 0
        case .username, .username_email:
            guard self.usernameEditingTime > 0 else {
                // Ignore if editing time is zero
                // Sometimes app will check the same username in very short time.
                return
            }

            let time = Int(Date().timeIntervalSince1970 - self.usernameEditingTime)
            self.challenge.timeUsername.append(time)

            self.usernameEditingTime = 0
        default:
            break
        }
    }

    func charactersTyped(chars: String, type: TextFieldType) throws {
        let value: String = chars.count > 1 ? "Paste": chars
        switch type {
        case .username, .username_email:
            self.challenge.keydownUsername.append(value)
            if chars.count > 1 {
                self.challenge.pasteUsername.append(chars)
            }
        case .recoveryMail, .recoveryPhone:
            self.challenge.keydownRecovery.append(value)
            if chars.count > 1 {
                self.challenge.pasteRecovery.append(chars)
            }
        default:
            break
        }
    }

    func charactersDeleted(chars: String, type: TextFieldType) {
        switch type {
        case .username, .username_email:
            self.challenge.keydownUsername.append("Backspace")
        case .recoveryMail, .recoveryPhone:
            self.challenge.keydownRecovery.append("Backspace")
        default:
            break
        }
    }

    func tap(textField: UITextField, type: TextFieldType) {
        switch type {
        case .username, .username_email:
            self.challenge.clickUsername += 1
        case .recoveryMail, .recoveryPhone:
            self.challenge.clickRecovery += 1
        default:
            break
        }
    }
}

extension PMChallenge {
    func getInterceptor(textField: UITextField) -> TextFieldDelegateInterceptor? {
        return interceptors.first { $0.textField == textField }
    }
}
