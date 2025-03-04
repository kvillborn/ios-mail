// Copyright (c) 2022 Proton AG
//
// This file is part of Proton Mail.
//
// Proton Mail is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Mail is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Mail. If not, see https://www.gnu.org/licenses/.

@testable import ProtonMail

class MockEventsService: EventsServiceProtocol {
    private(set) var wasFetchLatestEventIDCalled: Bool = false
    private(set) var wasProcessEventsCalled: Bool = false
    private(set) var wasProcessConversationEventsCalled: Bool = false

    var fetchLatestEventIDResult = EventLatestIDResponse()

    func fetchLatestEventID(completion: ((EventLatestIDResponse) -> Void)?) {
        wasFetchLatestEventIDCalled = true
        completion?(fetchLatestEventIDResult)
    }

    func processEvents(counts: [[String: Any]]?) {
        wasProcessEventsCalled = true
    }


    func processEvents(conversationCounts: [[String: Any]]?) {
        wasProcessConversationEventsCalled = true
    }
}
