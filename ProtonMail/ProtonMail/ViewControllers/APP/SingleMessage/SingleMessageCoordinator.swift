//
//  SingleMessageCoordinator.swift
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

import QuickLook
import SafariServices
import UIKit

class SingleMessageCoordinator: NSObject, CoordinatorDismissalObserver {

    weak var viewController: SingleMessageViewController?

    private let labelId: LabelID
    let message: MessageEntity
    private let coreDataService: CoreDataService
    private let user: UserManager
    private let navigationController: UINavigationController
    private let internetStatusProvider: InternetConnectionStatusProvider
    var pendingActionAfterDismissal: (() -> Void)?
    var goToDraft: ((MessageID) -> Void)?

    init(
        navigationController: UINavigationController,
        labelId: LabelID,
        message: MessageEntity,
        user: UserManager,
        coreDataService: CoreDataService =
            sharedServices.get(by: CoreDataService.self),
        internetStatusProvider: InternetConnectionStatusProvider = sharedServices.get()
    ) {
        self.navigationController = navigationController
        self.labelId = labelId
        self.message = message
        self.user = user
        self.coreDataService = coreDataService
        self.internetStatusProvider = internetStatusProvider
    }

    func start() {
        let singleMessageViewModelFactory = SingleMessageViewModelFactory()
        let viewModel = singleMessageViewModelFactory.createViewModel(
            labelId: labelId,
            message: message,
            user: user,
            systemUpTime: userCachedStatus,
            internetStatusProvider: internetStatusProvider,
            goToDraft: { [weak self] msgID in
                self?.navigationController.popViewController(animated: false)
                self?.goToDraft?(msgID)
            }
        )
        let viewController = SingleMessageViewController(coordinator: self, viewModel: viewModel)
        self.viewController = viewController
        navigationController.pushViewController(viewController, animated: true)
    }

    func follow(_ deeplink: DeepLink) {
        guard let node = deeplink.popFirst,
              let messageID = node.value else { return }
        self.presentExistedCompose(messageID: messageID)
    }

    func navigate(to navigationAction: SingleMessageNavigationAction) {
        switch navigationAction {
        case .compose(let contact):
            presentCompose(with: contact)
        case .contacts(let contact):
            presentAddContacts(with: contact)
        case .viewHeaders(let url):
            presentQuickLookView(url: url, subType: .headers)
        case .viewHTML(let url):
            presentQuickLookView(url: url, subType: .html)
        case .reply, .replyAll, .forward:
            presentCompose(action: navigationAction)
        case let .attachmentList(_, decryptedBody, attachments):
            presentAttachmentListView(decryptedBody: decryptedBody, attachments: attachments)
        case .url(url: let url):
            presentWebView(url: url)
        case .mailToUrl(let url):
            presentCompose(mailToURL: url)
        case .inAppSafari(url: let url):
            presentInAppSafari(url: url)
        case .addNewFolder:
            presentCreateFolder(type: .folder)
        case .addNewLabel:
            presentCreateFolder(type: .label)
        case .more:
            viewController?.moreButtonTapped()
        case .viewCypher(url: let url):
            presentQuickLookView(url: url, subType: .cypher)
        }
    }

    private func presentCompose(with contact: ContactVO) {
        let viewModel = ContainableComposeViewModel(
            msg: nil,
            action: .newDraft,
            msgService: user.messageService,
            user: user,
            coreDataContextProvider: sharedServices.get(by: CoreDataService.self)
        )
        viewModel.addToContacts(contact)

        presentCompose(viewModel: viewModel)
    }

    private func presentAddContacts(with contact: ContactVO) {
        let viewModel = ContactAddViewModelImpl(contactVO: contact,
                                                user: user,
                                                coreDataService: coreDataService)
        let newView = ContactEditViewController(viewModel: viewModel)
        let nav = UINavigationController(rootViewController: newView)
        self.viewController?.present(nav, animated: true)
    }

    private func presentQuickLookView(url: URL?, subType: PlainTextViewerViewController.ViewerSubType) {
        guard let fileUrl = url, let text = try? String(contentsOf: fileUrl) else { return }
        let viewer = PlainTextViewerViewController(text: text, subType: subType)
        try? FileManager.default.removeItem(at: fileUrl)
        self.navigationController.pushViewController(viewer, animated: true)
    }

    private func presentCompose(action: SingleMessageNavigationAction) {
        guard action.isReplyAllAction || action.isReplyAction || action.isForwardAction else { return }

        let composeAction: ComposeMessageAction
        switch action {
        case .reply:
            composeAction = .reply
        case .replyAll:
            composeAction = .replyAll
        case .forward:
            composeAction = .forward
        default:
            return
        }
        let contextProvider = sharedServices.get(by: CoreDataService.self)
        guard let msg = contextProvider.mainContext.object(with: message.objectID.rawValue) as? Message else { return }
        let viewModel = ContainableComposeViewModel(
            msg: msg,
            action: composeAction,
            msgService: user.messageService,
            user: user,
            coreDataContextProvider: sharedServices.get(by: CoreDataService.self)
        )

        presentCompose(viewModel: viewModel)
    }

    private func presentExistedCompose(messageID: String) {
        let context = coreDataService.mainContext
        guard let message = user.messageService.fetchMessages(withIDs: [messageID], in: context).first else {
            return
        }

        let viewModel = ContainableComposeViewModel(
            msg: message,
            action: .openDraft,
            msgService: user.messageService,
            user: user,
            coreDataContextProvider: sharedServices.get(by: CoreDataService.self)
        )

        delay(1) {
            self.presentCompose(viewModel: viewModel)
        }
    }

    private func presentAttachmentListView(decryptedBody: String?, attachments: [AttachmentInfo]) {
        let inlineCIDS = message.getCIDOfInlineAttachment(decryptedBody: decryptedBody)
        let viewModel = AttachmentListViewModel(
            attachments: attachments,
            user: user,
            inlineCIDS: inlineCIDS,
            dependencies: .init(fetchAttachment: FetchAttachment(dependencies: .init(apiService: user.apiService)))
        )
        let viewController = AttachmentListViewController(viewModel: viewModel)
        self.navigationController.pushViewController(viewController, animated: true)
    }

    private func presentWebView(url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url,
                                      options: [:],
                                      completionHandler: nil)
        }
    }

    private func presentInAppSafari(url: URL) {
        let safari = SFSafariViewController(url: url)
        self.viewController?.present(safari, animated: true, completion: nil)
    }

    private func presentCompose(mailToURL: URL) {
        guard let mailToData = mailToURL.parseMailtoLink() else { return }

        let coreDataService = sharedServices.get(by: CoreDataService.self)
        let viewModel = ContainableComposeViewModel(msg: nil,
                                                    action: .newDraft,
                                                    msgService: user.messageService,
                                                    user: user,
                                                    coreDataContextProvider: coreDataService)

        mailToData.to.forEach { recipient in
            viewModel.addToContacts(ContactVO(name: recipient, email: recipient))
        }

        mailToData.cc.forEach { recipient in
            viewModel.addCcContacts(ContactVO(name: recipient, email: recipient))
        }

        mailToData.bcc.forEach { recipient in
            viewModel.addBccContacts(ContactVO(name: recipient, email: recipient))
        }

        if let subject = mailToData.subject {
            viewModel.setSubject(subject)
        }

        if let body = mailToData.body {
            viewModel.setBody(body)
        }

        presentCompose(viewModel: viewModel)
    }

    private func presentCompose(viewModel: ContainableComposeViewModel) {
        let coordinator = ComposeContainerViewCoordinator(presentingViewController: self.viewController,
                                                          editorViewModel: viewModel)
        coordinator.start()
    }

    private func presentCreateFolder(type: PMLabelType) {
        let folderLabels = user.labelService.getMenuFolderLabels()
        let dependencies = LabelEditViewModel.Dependencies(userManager: user)
        let labelEditNavigationController = LabelEditStackBuilder.make(
            editMode: .creation,
            type: type,
            labels: folderLabels,
            dependencies: dependencies,
            coordinatorDismissalObserver: self
        )
        viewController?.navigationController?.present(labelEditNavigationController, animated: true, completion: nil)
    }
}
