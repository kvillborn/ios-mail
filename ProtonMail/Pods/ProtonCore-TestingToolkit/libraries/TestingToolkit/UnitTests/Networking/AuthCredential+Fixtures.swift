//
//  AuthCredantial+Fixtures.swift
//  ProtonCore-TestingToolkit - Created on 03.06.2021.
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

import ProtonCore_Networking

public extension AuthCredential {
    static var dummy: AuthCredential {
        .init(sessionID: .empty, accessToken: .empty, refreshToken: .empty, expiration: .distantFuture, userName: .empty, userID: .empty, privateKey: nil, passwordKeySalt: nil)
    }
    
    func updated(sessionID: String? = nil,
                 accessToken: String? = nil,
                 refreshToken: String? = nil,
                 expiration: Date? = nil,
                 userName: String? = nil,
                 userID: String? = nil,
                 privateKey: String?? = nil,
                 passwordKeySalt: String?? = nil) -> AuthCredential {
        AuthCredential(sessionID: sessionID ?? self.sessionID,
                       accessToken: accessToken ?? self.accessToken,
                       refreshToken: refreshToken ?? self.refreshToken,
                       expiration: expiration ?? self.expiration,
                       userName: userName ?? self.userName,
                       userID: userID ?? self.userID,
                       privateKey: privateKey ?? self.privateKey,
                       passwordKeySalt: passwordKeySalt ?? self.passwordKeySalt)
    }
    
    static func areEqualFieldwise(_ lhs: AuthCredential, _ rhs: AuthCredential) -> Bool {
        return lhs.sessionID == rhs.sessionID &&
               lhs.accessToken == rhs.accessToken &&
               lhs.refreshToken == rhs.refreshToken &&
               lhs.expiration == rhs.expiration &&
               lhs.userName == rhs.userName &&
               lhs.userID == rhs.userID &&
               lhs.privateKey == rhs.privateKey &&
               lhs.passwordKeySalt == rhs.passwordKeySalt
    }
}
