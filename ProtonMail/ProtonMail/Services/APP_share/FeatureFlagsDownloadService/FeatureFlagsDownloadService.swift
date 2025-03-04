// Copyright (c) 2021 Proton AG
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

import ProtonCore_Services

enum FeatureFlagKey: String, CaseIterable {
    case threading = "ThreadingIOS"
    case inAppFeedback = "InAppFeedbackIOS"
    case realNumAttachments = "RealNumAttachments"
    case scheduleSend = "ScheduledSend"
}

protocol FeatureFlagsSubscribeProtocol: AnyObject {
    func handleNewFeatureFlags(_ featureFlags: [String: Any])
}

protocol FeatureFlagsDownloadServiceProtocol {
    typealias FeatureFlagsDownloadCompletion =
        (Result<FeatureFlagsResponse, FeatureFlagsDownloadService.FeatureFlagFetchingError>) -> Void
}

/// This class is used to download the feature flags from the BE and send the flags to the subscribed objects.
class FeatureFlagsDownloadService: FeatureFlagsDownloadServiceProtocol {

    private let userID: UserID
    private let apiService: APIService
    private let sessionID: String
    private let subscribersTable: NSHashTable<AnyObject> = NSHashTable.weakObjects()
    var subscribers: [FeatureFlagsSubscribeProtocol] {
        subscribersTable.allObjects.compactMap { $0 as? FeatureFlagsSubscribeProtocol }
    }
    private(set) var lastFetchingTime: Date?
    private let scheduleSendEnableStatusProvider: ScheduleSendEnableStatusProvider
    private let realAttachmentsFlagProvider: RealAttachmentsFlagProvider

    init(
        userID: UserID,
        apiService: APIService,
        sessionID: String,
        scheduleSendEnableStatusProvider: ScheduleSendEnableStatusProvider,
        realAttachmentsFlagProvider: RealAttachmentsFlagProvider
    ) {
        self.userID = userID
        self.apiService = apiService
        self.sessionID = sessionID
        self.scheduleSendEnableStatusProvider = scheduleSendEnableStatusProvider
        self.realAttachmentsFlagProvider = realAttachmentsFlagProvider
    }

    func register(newSubscriber: FeatureFlagsSubscribeProtocol) {
        subscribersTable.add(newSubscriber)
    }

    enum FeatureFlagFetchingError: Error {
        case fetchingTooOften
        case networkError(Error)
        case selfIsReleased
    }

    func getFeatureFlags(completion: (FeatureFlagsDownloadCompletion)?) {
        if let time = self.lastFetchingTime,
            Date().timeIntervalSince1970 - time.timeIntervalSince1970 > 300.0 {
            completion?(.failure(.fetchingTooOften))
            return
        }

        let request = FeatureFlagsRequest()
        apiService.perform(request: request, response: FeatureFlagsResponse()) { [weak self] task, response in
            guard let self = self else {
                completion?(.failure(.selfIsReleased))
                return
            }
            if let error = task?.error {
                completion?(.failure(.networkError(error)))
                return
            }

            self.lastFetchingTime = Date()

            if !response.result.isEmpty {
                self.subscribers.forEach { $0.handleNewFeatureFlags(response.result) }
                if let realAttachment = response.result[FeatureFlagKey.realNumAttachments.rawValue] as? Bool {
                    self.realAttachmentsFlagProvider.set(
                        realAttachments: realAttachment,
                        sessionID: self.sessionID
                    )

                }
                if let isScheduleSendEnabled = response.result[FeatureFlagKey.scheduleSend.rawValue] as? Bool {
                    self.scheduleSendEnableStatusProvider.setScheduleSendStatus(
                        enable: isScheduleSendEnabled,
                        userID: self.userID
                    )
                }
            }
            completion?(.success(response))
        }
    }

    #if DEBUG
    func setLastFetchedTime(date: Date) {
        self.lastFetchingTime = date
    }
    #endif
}
