//
//  AuthDelegateMock.swift
//  ProtonCore-TestingToolkit - Created on 25.04.2022.
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
import ProtonCore_Services

public final class AuthDelegateMock: AuthDelegate {

    public init() {}

    @FuncStub(AuthDelegateMock.authCredential(sessionUID:), initialReturn: nil) public var getTokenAuthCredentialStub
    public func authCredential(sessionUID: String) -> AuthCredential? { getTokenAuthCredentialStub(sessionUID) }
    
    @FuncStub(AuthDelegateMock.credential(sessionUID:), initialReturn: nil) public var getTokenCredentialStub
    public func credential(sessionUID: String) -> Credential? { getTokenCredentialStub(sessionUID) }
    
    @FuncStub(AuthDelegateMock.onLogout) public var onLogoutStub
    public func onLogout(sessionUID uid: String) { onLogoutStub(uid) }
    
    @FuncStub(AuthDelegateMock.onUpdate) public var onUpdateStub
    public func onUpdate(credential: Credential, sessionUID: String) { onUpdateStub(credential, sessionUID) }
    
    @FuncStub(AuthDelegateMock.onRefresh) public var onRefreshStub
    public func onRefresh(sessionUID: String, service: APIService, complete: @escaping AuthRefreshResultCompletion) {
        onRefreshStub(sessionUID, service, complete)
    }
    
}
