//
//  Int+Extension.swift
//  Proton Mail - Created on 9/11/18.
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

extension Int {
    var toByteCount: String {
        // The default countStyle is file
        // 1000 bytes are shown as 1 KB
        let byteCountFormatter = ByteCountFormatter()
        return byteCountFormatter.string(fromByteCount: Int64(self))
    }

    var roundDownForScheduledSend: Int {
        let options = [0, 15, 30, 45]
        return options.last(where: { $0 <= self }) ?? self
    }
}
