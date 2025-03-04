//
//  ShareUnlockCoordinator.swift
//  Share - Created on 10/31/18.
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

import UIKit

class ShareUnlockCoordinator {
    var viewController: ShareUnlockViewController?
    private var nextCoordinator: SharePinUnlockCoordinator?

    internal weak var navigationController: UINavigationController?
    var services: ServiceFactory

    enum Destination: String {
        case pin, composer
    }

    init(navigation: UINavigationController?, services: ServiceFactory) {
        // parent navigation
        self.navigationController = navigation
        self.services = services
        // create self view controller
        self.viewController = ShareUnlockViewController(nibName: "ShareUnlockViewController", bundle: nil)
    }

    func start() {
        guard let viewController = viewController else { return }
        viewController.set(coordinator: self)
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func goPin() {
        // UI refe
        guard let navigationController = self.navigationController else { return }
        let pinView = SharePinUnlockCoordinator(navigation: navigationController,
                                                vm: ShareUnlockPinCodeModelImpl(unlock: self.services.get()),
                                                delegate: self)
        self.nextCoordinator = pinView
        pinView.start()
    }

    private func gotoComposer() {
        guard let controller = self.viewController,
              let navigationController = self.navigationController,
              let user = self.services.get(by: UsersManager.self).firstUser else {
            return
        }

        let coreDataService = self.services.get(by: CoreDataService.self)
        let editorViewModel = ContainableComposeViewModel(subject: controller.inputSubject,
                                                          body: controller.inputContent,
                                                          files: controller.files,
                                                          action: .newDraftFromShare,
                                                          msgService: user.messageService,
                                                          user: user,
                                                          coreDataContextProvider: coreDataService)

        let coordinator = ComposeContainerViewCoordinator(
            embeddingController: navigationController,
            editorViewModel: editorViewModel,
            services: self.services
        )
        coordinator.start()
    }

    func go(dest: Destination) {
        switch dest {
        case .pin:
            self.goPin()
        case .composer:
            self.gotoComposer()
        }
    }
}

extension ShareUnlockCoordinator: SharePinUnlockViewControllerDelegate {
    func cancel() {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            fatalError("Should have value")
        }
        let users = self.services.get(by: UsersManager.self)
        users.clean().done { [weak self] _ in
            let error = NSError(domain: bundleID, code: 0)
            self?.viewController?.extensionContext?.cancelRequest(withError: error)
        }.cauterize()
    }

    func next() {
        UnlockManager.shared.unlockIfRememberedCredentials(requestMailboxPassword: { })
    }
}
