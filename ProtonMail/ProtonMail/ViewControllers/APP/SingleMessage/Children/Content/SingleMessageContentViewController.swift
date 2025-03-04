import UIKit
import MBProgressHUD
import ProtonCore_UIFoundations

class SingleMessageContentViewController: UIViewController {

    let viewModel: SingleMessageContentViewModel

    private var headerViewController: HeaderViewController? {
        didSet {
            guard let headerViewController = headerViewController else {
                return
            }

            headerAnimationOn ?
                changeHeader(oldController: oldValue, newController: headerViewController) :
                manageHeaderViewControllers(oldController: oldValue, newController: headerViewController)
        }
    }

    private var contentOffsetToPreserve: CGPoint = .zero
    private let parentScrollView: UIScrollView
    private let navigationAction: (SingleMessageNavigationAction) -> Void
    let customView: SingleMessageContentView
    private var isExpandingHeader = false

    private(set) var messageBodyViewController: NewMessageBodyViewController!
    private(set) var bannerViewController: BannerViewController?
    private(set) var editScheduleBannerController: BannerViewController?
    private(set) var attachmentViewController: AttachmentViewController?
    private let applicationStateProvider: ApplicationStateProvider

    private(set) var shouldReloadWhenAppIsActive = false

    init(viewModel: SingleMessageContentViewModel,
         parentScrollView: UIScrollView,
         viewMode: ViewMode,
         navigationAction: @escaping (SingleMessageNavigationAction) -> Void,
         applicationStateProvider: ApplicationStateProvider = UIApplication.shared) {
        self.viewModel = viewModel
        self.parentScrollView = parentScrollView
        self.navigationAction = navigationAction
        let moreThanOneContact = viewModel.message.isHavingMoreThanOneContact
        let replyState = HeaderContainerView.ReplyState.from(moreThanOneContact: moreThanOneContact,
                                                             isScheduled: viewModel.message.contains(location: .scheduled))
        self.customView =  SingleMessageContentView(replyState: replyState)
        self.applicationStateProvider = applicationStateProvider
        super.init(nibName: nil, bundle: nil)

        self.messageBodyViewController =
            NewMessageBodyViewController(viewModel: viewModel.messageBodyViewModel, parentScrollView: self, viewMode: viewMode)
        self.messageBodyViewController.delegate = self

        if viewModel.message.expirationTime != nil {
            showBanner()
        }
        showEditScheduleBanner()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        view = customView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.set(uiDelegate: self)
        viewModel.updateErrorBanner = { [weak self] error in
            if let error = error {
                self?.showBanner()
                self?.bannerViewController?.showErrorBanner(error: error)
            } else {
                self?.bannerViewController?.hideBanner(type: .error)
            }
        }
        customView.showHideHistoryButtonContainer.showHideHistoryButton.isHidden = !viewModel.messageInfoProvider.hasStrippedVersion
        customView.showHideHistoryButtonContainer.showHideHistoryButton.addTarget(self, action: #selector(showHide), for: .touchUpInside)
        viewModel.messageHadChanged = { [weak self] in
            guard let self = self else { return }
            self.embedAttachmentViewIfNeeded()
        }

        viewModel.startMonitorConnectionStatus { [weak self] in
            return self?.applicationStateProvider.applicationState == .active
        } reloadWhenAppIsActive: { [weak self] value in
            self?.shouldReloadWhenAppIsActive = value
        }

        viewModel.showProgressHub = { [weak self] in
            guard let self = self else { return }
            MBProgressHUD.showAdded(to: self.view, animated: true)
        }

        viewModel.hideProgressHub = { [weak self] in
            guard let self = self else { return }
            MBProgressHUD.hide(for: self.view, animated: true)
        }

        addObservations()
        setUpHeaderActions()
        embedChildren()
        setUpFooterButtons()

        viewModel.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        spotlightFeatures()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 12.0, *) {
            let isDarkModeStyle = traitCollection.userInterfaceStyle == .dark
            viewModel.sendMetricAPIIfNeeded(isDarkModeStyle: isDarkModeStyle)
        }
    }

    @objc private func showHide(_ sender: UIButton) {
        sender.isHidden = true
        viewModel.messageInfoProvider.displayMode.toggle()
        delay(0.5) {
            sender.isHidden = false
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setUpFooterButtons() {
        if viewModel.message.contains(location: .scheduled) {
            customView.footerButtons.removeFromSuperview()
        } else if !viewModel.message.isHavingMoreThanOneContact {
            customView.footerButtons.stackView.distribution = .fillEqually
            customView.footerButtons.replyAllButton.removeFromSuperview()
        } else {
            customView.footerButtons.replyAllButton.tap = { [weak self] in
                self?.replyAllButtonTapped()
            }
        }

        customView.footerButtons.replyButton.tap = { [weak self] in
            self?.replyButtonTapped()
        }
        customView.footerButtons.forwardButton.tap = { [weak self] in
            self?.forwardButtonTapped()
        }
    }

    private func replyButtonTapped() {
        guard !self.viewModel.user.isStorageExceeded else {
            LocalString._storage_exceeded.alertToastBottom()
            return
        }
        let messageId = viewModel.message.messageID
        let action: SingleMessageNavigationAction = .reply(messageId: messageId)
        navigationAction(action)
    }

    private func replyAllButtonTapped() {
        guard !self.viewModel.user.isStorageExceeded else {
            LocalString._storage_exceeded.alertToastBottom()
            return
        }
        let messageId = viewModel.message.messageID
        let action = SingleMessageNavigationAction.replyAll(messageId: messageId)
        navigationAction(action)
    }

    private func forwardButtonTapped() {
        guard !self.viewModel.user.isStorageExceeded else {
            LocalString._storage_exceeded.alertToastBottom()
            return
        }
        let messageId = viewModel.message.messageID
        let action = SingleMessageNavigationAction.forward(messageId: messageId)
        navigationAction(action)
    }

    @objc
    private func moreButtonTapped() {
        navigationAction(.more(messageId: viewModel.message.messageID))
    }

    @objc
    private func replyActionButtonTapped() {
        switch customView.replyState {
        case .reply:
            replyButtonTapped()
        case .replyAll:
            replyAllButtonTapped()
        case .none:
            return
        }
    }

    private func showEditScheduleBanner() {
        guard self.editScheduleBannerController == nil && viewModel.message.isScheduledSend else {
            return
        }
        let controller = BannerViewController(viewModel: viewModel.bannerViewModel, isScheduleBannerOnly: true)
        self.editScheduleBannerController = controller
        embed(controller, inside: customView.editScheduleSendBannerContainer)
    }

    private func showBanner() {
        guard self.bannerViewController == nil else {
            return
        }
        let controller = BannerViewController(viewModel: viewModel.bannerViewModel)
        controller.delegate = self
        self.bannerViewController = controller
        embed(controller, inside: customView.bannerContainer)
    }

    private func hideBanner() {
        guard let controler = self.bannerViewController else {
            return
        }
        unembed(controler)
        self.bannerViewController = nil
    }

    private func manageHeaderViewControllers(oldController: UIViewController?, newController: UIViewController) {
        if let oldController = oldController {
            unembed(oldController)
        }

        embed(newController, inside: self.customView.messageHeaderContainer.contentContainer)
    }

    private func changeHeader(oldController: UIViewController?, newController: UIViewController) {
        oldController?.willMove(toParent: nil)
        newController.view.translatesAutoresizingMaskIntoConstraints = false

        self.addChild(newController)
        self.customView.messageHeaderContainer.contentContainer.addSubview(newController.view)

        let oldBottomConstraint = customView.messageHeaderContainer.contentContainer
            .constraints.first(where: { $0.firstAttribute == .bottom })

        newController.view.alpha = 0

        [
            newController.view.topAnchor.constraint(equalTo: customView.messageHeaderContainer.contentContainer.topAnchor),
            newController.view.leadingAnchor.constraint(equalTo: customView.messageHeaderContainer.contentContainer.leadingAnchor),
            newController.view.trailingAnchor.constraint(equalTo: customView.messageHeaderContainer.contentContainer.trailingAnchor)
        ].activate()
        
        let bottomConstraint = newController.view.bottomAnchor
            .constraint(equalTo: customView.messageHeaderContainer.contentContainer.bottomAnchor)
        
        UIView.setAnimationsEnabled(true)
        
        oldBottomConstraint?.isActive = false
        bottomConstraint.isActive = true
        
        UIView.animate(withDuration: 0.25) {
            newController.view.alpha = 1
            oldController?.view.alpha = 0
        } completion: { [weak self] _ in
            newController.view.layoutIfNeeded()
            oldController?.view.removeFromSuperview()
            oldController?.removeFromParent()
            newController.didMove(toParent: self)
            self?.viewModel.recalculateCellHeight?(false)
        }
    }

    private func addObservations() {
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(restoreOffset),
                                                   name: UIWindowScene.willEnterForegroundNotification,
                                                   object: nil)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(saveOffset),
                                                   name: UIWindowScene.didEnterBackgroundNotification,
                                                   object: nil)
            NotificationCenter.default
                .addObserver(self,
                             selector: #selector(willBecomeActive),
                             name: UIScene.willEnterForegroundNotification,
                             object: nil)
        } else {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(restoreOffset),
                                                   name: UIApplication.willEnterForegroundNotification,
                                                   object: nil)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(saveOffset),
                                                   name: UIApplication.didEnterBackgroundNotification,
                                                   object: nil)
            NotificationCenter.default
                .addObserver(self,
                             selector: #selector(willBecomeActive),
                             name: UIApplication.willEnterForegroundNotification,
                             object: nil)
        }
    }

    @objc
    private func expandButton() {
        guard isExpandingHeader == false else { return }
        viewModel.isExpanded.toggle()
    }

    private func setUpHeaderActions() {
        // Action
        customView.messageHeaderContainer.moreControl.addTarget(self, action: #selector(self.moreButtonTapped), for: .touchUpInside)
        customView.messageHeaderContainer.replyControl.addTarget(self, action: #selector(self.replyActionButtonTapped), for: .touchUpInside)

    }

    private func embedChildren() {
        precondition(messageBodyViewController != nil)
        embed(messageBodyViewController, inside: customView.messageBodyContainer)
        if let headerViewController = headerViewController {
            embed(headerViewController, inside: customView.messageHeaderContainer.contentContainer)
        }
        embedAttachmentViewIfNeeded()
        embedHeaderController()
    }

    private func embedAttachmentViewIfNeeded() {
        guard self.attachmentViewController == nil else { return }
        if viewModel.attachmentViewModel.numberOfAttachments != 0 {
            let attachmentVC = AttachmentViewController(viewModel: viewModel.attachmentViewModel)
            attachmentVC.delegate = self
            embed(attachmentVC, inside: customView.attachmentContainer)
            attachmentViewController = attachmentVC
        }
    }

    private var headerAnimationOn = true

    private func embedHeaderController() {
        viewModel.embedExpandedHeader = { [weak self] viewModel in
            let viewController = ExpandedHeaderViewController(viewModel: viewModel)
            viewController.contactTapped = {
                self?.presentActionSheet(context: $0)
            }
            viewController.observeHideDetails {
                self?.expandButton()
            }
            self?.headerViewController = viewController
        }

        viewModel.embedNonExpandedHeader = { [weak self] viewModel in
            let header = NonExpandedHeaderViewController(viewModel: viewModel)
            header.observeShowDetails {
                self?.expandButton()
            }
            header.contactTapped = {
                self?.presentActionSheet(context: $0)
            }
            self?.headerViewController = header
        }

        headerAnimationOn.toggle()
        viewModel.isExpanded = viewModel.isExpanded
        headerAnimationOn.toggle()
    }

    private func presentActionSheet(context: MessageHeaderContactContext) {
        var title = context.contact.title
        if context.type == .sender {
            title = viewModel.messageInfoProvider.senderName
        }
        let actionSheet = PMActionSheet.messageDetailsContact(for: title, subTitle: context.contact.subtitle) { [weak self] action in
            self?.dismissActionSheet()
            self?.handleAction(context: context, action: action)
        }
        actionSheet.presentAt(navigationController ?? self, hasTopConstant: false, animated: true)
    }

    private func handleAction(context: MessageHeaderContactContext, action: MessageDetailsContactActionSheetAction) {
        switch action {
        case .addToContacts:
            navigationAction(.contacts(contact: context.contact))
        case .composeTo:
            guard !self.viewModel.user.isStorageExceeded else {
                LocalString._storage_exceeded.alertToastBottom(view: self.view)
                return
            }
            navigationAction(.compose(contact: context.contact))
        case .copyAddress:
            UIPasteboard.general.string = context.contact.email
        case .copyName:
            UIPasteboard.general.string = context.contact.name
        case .close:
            break
        }
    }

    @objc
    private func willBecomeActive(_ notification: Notification) {
        if shouldReloadWhenAppIsActive {
            viewModel.downloadDetails()
            shouldReloadWhenAppIsActive = false
        }
    }

    private func spotlightFeatures() {
        if viewModel.shouldSpotlightTrackerProtection {
            spotlightTrackerProtection()
        }
    }
}

extension SingleMessageContentViewController: NewMessageBodyViewControllerDelegate {
    func openMailUrl(_ mailUrl: URL) {
        navigationAction(.mailToUrl(url: mailUrl))
    }

    func openUrl(_ url: URL) {
        let browserSpecificUrl = viewModel.linkOpener.deeplink(to: url) ?? url
        switch viewModel.linkOpener {
        case .inAppSafari:
            let supports = ["https", "http"]
            let scheme = browserSpecificUrl.scheme ?? ""
            guard supports.contains(scheme) else {
                self.showUnsupportAlert(url: browserSpecificUrl)
                return
            }
            navigationAction(.inAppSafari(url: browserSpecificUrl))
        default:
            navigationAction(.url(url: browserSpecificUrl))
        }
    }

    func openFullCryptoPage() {
        guard let url = self.viewModel.getCypherURL() else { return }
        navigationAction(.viewCypher(url: url))
    }

    private func showUnsupportAlert(url: URL) {
        let message = LocalString._unsupported_url
        let open = LocalString._general_open_button
        let alertController = UIAlertController(title: LocalString._general_alert_title,
                                                message: message,
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: open,
                                                style: .default,
                                                handler: { _ in
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }))
        alertController.addAction(UIAlertAction(title: LocalString._general_cancel_button,
                                                style: .cancel,
                                                handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

    @objc
    private func tryDecryptionAgain() {
        if let vi = self.navigationController?.view {
            MBProgressHUD.showAdded(to: vi, animated: true)
        }
        viewModel.messageInfoProvider.tryDecryptionAgain { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let vi = self.navigationController?.view {
                    MBProgressHUD.hide(for: vi, animated: true)
                }
            }
        }
    }
}

extension SingleMessageContentViewController: AttachmentViewControllerDelegate {
    func openAttachmentList(with attachments: [AttachmentInfo]) {
        let messageID = viewModel.message.messageID
        // Attachment list needs to check if the body contains content IDs
        // So needs to use full message body or it could miss inline image in the quote
        let body = viewModel.messageInfoProvider.bodyParts?.body(for: .expanded)
        navigationAction(.attachmentList(messageId: messageID, decryptedBody: body, attachments: attachments))
    }
}

extension SingleMessageContentViewController: BannerViewControllerDelegate {
    func hideBannerController() {
        hideBanner()
    }

    func showBannerController() {
        showBanner()
    }

    func loadEmbeddedImage() {
        viewModel.messageInfoProvider.embeddedContentPolicy = .allowed
    }

    func handleMessageExpired() {
        self.viewModel.deleteExpiredMessages()
        self.navigationController?.popViewController(animated: true)
    }

    func loadRemoteContent() {
        viewModel.messageInfoProvider.remoteContentPolicy = .allowed
    }

    func reloadImagesWithoutProtection() {
        viewModel.messageInfoProvider.reloadImagesWithoutProtection()
    }
}

extension SingleMessageContentViewController: ScrollableContainer {
    var scroller: UIScrollView {
        return parentScrollView
    }

    func propagate(scrolling delta: CGPoint, boundsTouchedHandler: () -> Void) {
        let scrollView = parentScrollView
        UIView.animate(withDuration: 0.001) { // hackish way to show scrolling indicators on tableView
            scrollView.flashScrollIndicators()
        }
        let maxOffset = scrollView.contentSize.height - scrollView.frame.size.height
        guard maxOffset > 0 else { return }

        let yOffset = scrollView.contentOffset.y + delta.y

        if yOffset < 0 { // not too high
            scrollView.setContentOffset(.zero, animated: false)
            boundsTouchedHandler()
        } else if yOffset > maxOffset { // not too low
            scrollView.setContentOffset(.init(x: 0, y: maxOffset), animated: false)
            boundsTouchedHandler()
        } else {
            scrollView.contentOffset = .init(x: 0, y: yOffset)
        }
    }

    @objc
    func saveOffset() {
        self.contentOffsetToPreserve = scroller.contentOffset
    }

    @objc
    func restoreOffset() {
        scroller.setContentOffset(self.contentOffsetToPreserve, animated: false)
    }
}

extension SingleMessageContentViewController: SingleMessageContentUIProtocol {
    func updateContentBanner(
        shouldShowRemoteContentBanner: Bool,
        shouldShowEmbeddedContentBanner: Bool,
        shouldShowImageProxyFailedBanner: Bool
    ) {
        let shouldShowRemoteContentBanner =
            shouldShowRemoteContentBanner && !viewModel.bannerViewModel.shouldAutoLoadRemoteContent
        let shouldShowEmbeddedImageBanner =
            shouldShowEmbeddedContentBanner && !viewModel.bannerViewModel.shouldAutoLoadEmbeddedImage

        showBanner()
        bannerViewController?.showContentBanner(remoteContent: shouldShowRemoteContentBanner,
                                                embeddedImage: shouldShowEmbeddedImageBanner,
                                                imageProxyFailure: shouldShowImageProxyFailedBanner)
    }

    func setDecryptionErrorBanner(shouldShow: Bool) {
        if shouldShow {
            showBanner()
            bannerViewController?.showDecryptionBanner { [weak self] in
                self?.tryDecryptionAgain()
            }
        } else {
            bannerViewController?.hideDecryptionBanner()
        }
    }

    func update(hasStrippedVersion: Bool) {
        customView.showHideHistoryButtonContainer.showHideHistoryButton.isHidden = !hasStrippedVersion
    }

    func updateAttachmentBannerIfNeeded() {
        embedAttachmentViewIfNeeded()
	}

    func trackerProtectionSummaryChanged() {
        headerViewController?.trackerProtectionSummaryChanged()
    }

    private func spotlightTrackerProtection() {
        guard let spotlightContainerView = navigationController?.view else {
            assertionFailure("View outside of view hierarchy")
            return
        }

        let spotlightView = makeSpotlightView()

        guard let spotlightableView = headerViewController?.spotlightableView else {
            return
        }

        viewModel.userHasSeenSpotlightForTrackerProtection()

        let frameInContainer = spotlightableView.convert(spotlightableView.bounds, to: spotlightContainerView)
        spotlightView.presentOn(view: spotlightContainerView, targetFrame: frameInContainer)
    }

    private func makeSpotlightView() -> SpotlightView {
        SpotlightView(
            title: L11n.EmailTrackerProtection.spotlight_title,
            message: viewModel.spotlightMessage,
            icon: Asset.trackingProtectionSpotlightIcon
        )
    }
}
