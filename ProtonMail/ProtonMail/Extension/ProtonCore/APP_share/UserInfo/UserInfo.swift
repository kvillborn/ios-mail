//
//  UserInfo.swift
//  Proton Mail
//
//
//  Copyright (c) 2019 Proton AG
//
//  This file is part of Proton Mail.
//
//  Proton Mail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton Mail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton Mail.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import GoLibs
import ProtonCore_DataModel

extension UserInfo {

    var addressPrivateKeysArray: [Data] {
        var out: [Data] = []
        var error: NSError?
        for addr in userAddresses {
            for key in addr.keys {
                if let privK = ArmorUnarmor(key.privateKey, &error) {
                    out.append(privK)
                }
            }
        }
        return out
    }

    var isAutoLoadRemoteContentEnabled: Bool {
        if Self.isImageProxyAvailable {
            return hideRemoteImages == 0
        } else {
            return showImages.contains(.remote)
        }
    }

    var isAutoLoadEmbeddedImagesEnabled: Bool {
        if Self.isImageProxyAvailable {
            return hideEmbeddedImages == 0
        } else {
            return showImages.contains(.embedded)
        }
    }
}
