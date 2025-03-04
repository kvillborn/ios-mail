//
//  MenuRobot.swift
//  ProtonMailUITests
//
//  Created by denys zelenchuk on 03.07.20.
//  Copyright © 2020 Proton Mail. All rights reserved.
//

import XCTest
import ProtonCore_CoreTranslation
import ProtonCore_TestingToolkit
import pmtest

fileprivate struct id {
    static let logoutCell = "MenuItemTableViewCell.Sign_out"
    static let logoutConfirmButton = NSLocalizedString("Sign Out", comment: "comment")
    static let inboxStaticText = "MenuItemTableViewCell.\(LocalString._menu_inbox_title)"
    static let reportBugStaticText = "MenuItemTableViewCell.Report_a_bug"
    static let spamStaticText = "MenuItemTableViewCell.\(LocalString._menu_spam_title)"
    static let trashStaticText = "MenuItemTableViewCell.\(LocalString._menu_trash_title)"
    static let sentStaticText = "MenuItemTableViewCell.\(LocalString._menu_sent_title)"
    static let contactsStaticText = "MenuItemTableViewCell.\(LocalString._menu_contacts_title)"
    static let draftsStaticText = "MenuItemTableViewCell.\(LocalString._menu_drafts_title)"
    static let settingsStaticText = "MenuItemTableViewCell.\(LocalString._menu_settings_title)"
    static let subscriptionStaticText = "MenuItemTableViewCell.\(LocalString._menu_service_plan_title)"
    static let sidebarHeaderViewOtherIdentifier = "MenuViewController.primaryUserview"
    static let manageAccountsStaticTextLabel = CoreString._as_manage_accounts
    static let primaryViewIdentifier = "AccountSwitcher.primaryView"
    static let primaryUserViewIdentifier = "MenuViewController.primaryUserview"
    static let primaryUserNameTextIdentifier = "AccountSwitcher.username"
    static let primaryUserMailTextIdentifier = "AccountSwitcher.usermail"
    static func primaryUserMailStaticTextIdentifier(_ name: String) -> String { return "\(name).usermail" }
    static let iapErrorAlertTitle = LocalString._general_alert_title
    static let forceUpgrateAlertTitle = CoreString._fu_alert_title
    static let forceUpgrateAlertMessage = "Test error description"
    static let forceUpgrateLearnMoreButton = CoreString._fu_alert_learn_more_button
    static let forceUpgrateUpdateButton = CoreString._fu_alert_update_button
    static let signInButtonLabel = CoreString._ls_sign_in_button
    static func signInButtonIdentifier(_ name: String) -> String { return "\(name).signInBtn" }
    static func userAccountCellIdentifier(_ name: String) -> String { return "AccountSwitcherCell.\(name)" }
    static func shortNameStaticTextdentifier(_ email: String) -> String { return "\(email).shortName" }
    static func displayNameStaticTextdentifier(_ email: String) -> String { return "\(email).displayName" }
    static func folderLabelCellIdentifier(_ name: String) -> String { return "MenuItemTableViewCell.\(name)" }
}

/**
 Represents Menu view.
*/
class MenuRobot: CoreElements {
    
    var verify = Verify()
    
    func logoutUser() -> LoginRobot {
        return logout()
            .confirmLogout()
    }
    
    @discardableResult
    func sent() -> SentRobot {
        cell(id.sentStaticText).swipeDownUntilVisible().tap()
        return SentRobot()
    }
    
    @discardableResult
    func contacts() -> ContactsRobot {
        cell(id.contactsStaticText).swipeUpUntilVisible().tap()
        return ContactsRobot()
    }
    
    @discardableResult
    func subscriptionAsHumanVerification() -> HumanVerificationRobot {
        // fake subscription item leads to human verification (by http mock)
        cell(id.subscriptionStaticText).swipeUpUntilVisible().tap()
        return HumanVerificationRobot()
    }
    
    func subscriptionAsForceUpgrade() -> MenuRobot{
        // fake subscription item leads to force upgrade (by http mock)
        cell(id.subscriptionStaticText).swipeUpUntilVisible().tap()
        return MenuRobot()
    }
    
    func drafts() -> DraftsRobot {
        cell(id.draftsStaticText).swipeDownUntilVisible().tap()
        return DraftsRobot()
    }
    
    func inbox() -> InboxRobot {
        cell(id.inboxStaticText).swipeDownUntilVisible().tap()
        return InboxRobot()
    }
    
    func spams() -> SpamRobot {
        cell(id.spamStaticText).swipeDownUntilVisible().tap()
        return SpamRobot()
    }
    
    func trash() -> TrashRobot {
        cell(id.trashStaticText).swipeDownUntilVisible().tap()
        return TrashRobot()
    }
    
    func accountsList() -> MenuAccountListRobot {
        button(id.sidebarHeaderViewOtherIdentifier).tap()
        return MenuAccountListRobot()
    }
    
    func folderOrLabel(_ name: String) -> LabelFolderRobot {
        cell(id.folderLabelCellIdentifier(name.replacingOccurrences(of: " ", with: "_"))).swipeUpUntilVisible().tap()
        return LabelFolderRobot()
    }
    
    @discardableResult
    func reports() -> ReportRobot {
        cell(id.reportBugStaticText).swipeUpUntilVisible().tap()
        return ReportRobot()
    }
    
    func settings() -> SettingsRobot {
        cell(id.settingsStaticText).swipeUpUntilVisible().tap()
        return SettingsRobot()
    }
    
    private func logout() -> MenuRobot {
        cell(id.logoutCell).swipeUpUntilVisible().tap()
        return self
    }
    
    private func confirmLogout() -> LoginRobot {
        button(id.logoutConfirmButton).tap()
        return LoginRobot()
    }
    
    /**
     MenuAccountListRobot class contains actions and verifications for Account list functionality inside Menu drawer
     */
    class MenuAccountListRobot: CoreElements {
        
        var verify = Verify()

        func manageAccounts() -> AccountManagerRobot {
            staticText(id.manageAccountsStaticTextLabel).tap()
            return AccountManagerRobot()
        }

        func switchToAccount(_ user: User) -> InboxRobot {
            cell(id.userAccountCellIdentifier(user.name)).tap()
            return InboxRobot()
        }

        func dismiss() -> MenuRobot {
            let normalized = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            let coordinate = normalized.withOffset(CGVector(dx: 10, dy: 400))
            coordinate.tap()
            return MenuRobot()
        }

        /**
         Contains all the validations that can be performed by [MenuAccountListRobot].
         */
        class Verify: CoreElements {

            func accountAdded(_ user: User) {
                staticText(id.primaryUserMailStaticTextIdentifier(user.name))
                    .checkExists()
                    .checkHasLabel(user.email)
            }
            
            func accountAdded(_ primaryUser: User, _ secondaryUser: User) {
                staticText(id.primaryUserMailStaticTextIdentifier(secondaryUser.name))
                    .checkExists()
                    .checkHasLabel(primaryUser.email)
            }
            
            func accountShortNameIsCorrect(_ shortName: String) {
                staticText(shortName).wait().checkExists()
            }
            
            func accountAtPositionSignedOut(_ position: Int) {
//                cell(id.userAccountCellIdentifier).byIndex(position)
//                    .onChild(button(id.signInButtonIdentifier))
//                    .checkExists()
//                    .checkHasLabel(id.signInButtonLabel)
            }
            
            func accountSignedOut(_ shortName: String) {
                cell(id.userAccountCellIdentifier(shortName))
                    .onChild(button(id.signInButtonIdentifier(shortName)))
                    .checkExists()
                    .checkHasLabel(id.signInButtonLabel)
            }
        }
    }
    
    @discardableResult
    func paymentsErrorDialog() -> PaymentsErrorDialogRobot {
        return PaymentsErrorDialogRobot()
    }
    
    class PaymentsErrorDialogRobot {
        
        let verify = Verify()
        
        class Verify: CoreElements {
            func invalidCredentialDialogDisplay() {
                staticText(id.iapErrorAlertTitle).wait().checkExists()
            }
        }
    }
    
    @discardableResult
    func forceUpgradeDialog() -> ForceUpgradeDialogRobot {
        return ForceUpgradeDialogRobot()
    }
    
    class ForceUpgradeDialogRobot: CoreElements {
        
        let verify = Verify()
        
        class Verify: CoreElements {
            @discardableResult
            func checkDialog() -> ForceUpgradeDialogRobot {
                staticText(id.forceUpgrateAlertTitle).wait().checkExists()
                staticText(id.forceUpgrateAlertMessage).wait().checkExists()
                return ForceUpgradeDialogRobot()
            }
        }

        @discardableResult
        func learnMoreButtonTap() -> ForceUpgradeDialogRobot {
            button(id.forceUpgrateLearnMoreButton).tap()
            return ForceUpgradeDialogRobot()
        }

        @discardableResult
        func upgradeButtonTap() -> ForceUpgradeDialogRobot {
            button(id.forceUpgrateUpdateButton).tap()
            return ForceUpgradeDialogRobot()
        }

        func back() -> ForceUpgradeDialogRobot {
            XCUIApplication().activate()
            return ForceUpgradeDialogRobot()
        }
    }
    
    /**
     Contains all the validations that can be performed by MenuRobot.
    */
    class Verify: CoreElements {
        func currentAccount(_ account: User) {
            button(id.primaryUserViewIdentifier).checkContainsLabel(account.name)
        }
    }
}
