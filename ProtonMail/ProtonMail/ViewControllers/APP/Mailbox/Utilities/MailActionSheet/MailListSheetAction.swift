//
//  MailListSheetAction.swift
//  Proton Mail
//
//
//  Copyright (c) 2021 Proton AG
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

enum MailListSheetAction: Equatable {
    case star
    case unstar
    case markRead
    case markUnread
    case remove
    case delete
    case moveToArchive
    case moveToSpam
    case dismiss
    case labelAs
    case moveTo
    case moveToInbox

    var group: MessageViewActionSheetGroup {
        switch self {
        case .star, .unstar, .markRead, .markUnread, .labelAs:
            return .manage
        case .remove, .delete, .moveToArchive, .moveToSpam, .moveTo, .moveToInbox:
            return .moveMessage
        case .dismiss:
            return .noGroup
        }
    }
}
