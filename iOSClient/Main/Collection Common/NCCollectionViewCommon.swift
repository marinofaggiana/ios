//
//  NCCollectionViewCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/09/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//  Copyright © 2021 Henrik Storch. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import NCCommunication

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate, UIContextMenuInteractionDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    weak var appDelegate = UIApplication.shared.delegate as? AppDelegate

    internal let refreshControl = UIRefreshControl()
    internal var searchController: UISearchController?
    internal var emptyDataSet: NCEmptyDataSet?
    internal var backgroundImageView = UIImageView()
    internal var serverUrl: String = ""
    internal var isEncryptedFolder = false
    internal var isEditMode = false
    internal var selectOcId: [String] = []
    internal var metadatasSource: [tableMetadata] = []
    internal var metadataFolder: tableMetadata?
    internal var dataSource = NCDataSource()
    internal var richWorkspaceText: String?
    internal var header: UIView?

    internal var layoutForView: NCGlobal.layoutForViewType?

    internal var autoUploadFileName = ""
    internal var autoUploadDirectory = ""

    internal var listLayout: NCListLayout!
    internal var gridLayout: NCGridLayout!

    internal let headerHeight: CGFloat = 50
    internal var headerRichWorkspaceHeight: CGFloat = 0
    internal let footerHeight: CGFloat = 100

    internal var timerInputSearch: Timer?
    internal var literalSearch: String?
    internal var isSearching: Bool = false

    internal var isReloadDataSourceNetworkInProgress: Bool = false

    internal var pushed: Bool = false

    // DECLARE
    internal var layoutKey = ""
    internal var titleCurrentFolder = ""
    internal var enableSearchBar: Bool = false
    internal var emptyImage: UIImage?
    internal var emptyTitle: String = ""
    internal var emptyDescription: String = ""

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.presentationController?.delegate = self

        collectionView.alwaysBounceVertical = true

        if enableSearchBar {
            searchController = UISearchController(searchResultsController: nil)
            searchController?.searchResultsUpdater = self
            searchController?.obscuresBackgroundDuringPresentation = false
            searchController?.delegate = self
            searchController?.searchBar.delegate = self
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        }

        // Cell
        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        collectionView.register(UINib(nibName: "NCTransferCell", bundle: nil), forCellWithReuseIdentifier: "transferCell")

        // Header
        collectionView.register(UINib(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")

        // Footer
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        // Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.action(for: .valueChanged) { _ in
            self.reloadDataSourceNetwork(forced: true)
        }

        // Empty
        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: headerHeight, delegate: self)

        // Long Press on CollectionView
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressCollecationView(_:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(longPressedGesture)

        // Notification

        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)

        changeTheming()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // ACTIVE
        appDelegate?.activeViewController = self

        //
        NotificationCenter.default.addObserver(
            self, selector: #selector(closeRichWorkspaceWebView),
            name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(changeStatusFolderE2EE(_:)),
            name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setNavigationItem), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(reloadDataSourceNetworkForced(_:)),
            name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(downloadCancelFile(_:)),
            name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(uploadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadCancelFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)

        if let appDelegate = appDelegate, serverUrl.isEmpty {
            appDelegate.activeServerUrl = NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account)
        } else {
            appDelegate?.activeServerUrl = serverUrl
        }

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        setNavigationItem()

        changeTheming()
        reloadDataSource()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reloadDataSourceNetwork()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)

        pushed = false
    }

    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {
        let viewController = presentationController.presentedViewController
        if viewController is NCViewerRichWorkspaceWebView {
            closeRichWorkspaceWebView()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override var canBecomeFirstResponder: Bool { return true }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        changeTheming()
    }

    // MARK: - NotificationCenter

    @objc func initialize() {

        guard let account = appDelegate?.account, !account.isEmpty else { return }

        // Search
        if searchController?.isActive ?? false {
            searchController?.isActive = false
        }

        // Select
        if isEditMode {
            isEditMode = !isEditMode
            selectOcId.removeAll()
        }

        if self.view?.window != nil {
            if serverUrl.isEmpty {
                appDelegate?.activeServerUrl = NCUtilityFileSystem.shared.getHomeServer(account: account)
            } else {
                appDelegate?.activeServerUrl = serverUrl
            }

            appDelegate?.listFilesVC.removeAll()
            appDelegate?.listFavoriteVC.removeAll()
            appDelegate?.listOfflineVC.removeAll()
        }

        if !serverUrl.isEmpty {
            self.navigationController?.popToRootViewController(animated: false)
        }

        setNavigationItem()
        reloadDataSource()
        changeTheming()
    }

    @objc func changeTheming() {

        view.backgroundColor = NCBrandColor.shared.systemBackground
        collectionView.backgroundColor = NCBrandColor.shared.systemBackground
        refreshControl.tintColor = .gray

        layoutForView = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }

        // IMAGE BACKGROUND
        if let imageBackgroud = layoutForView?.imageBackgroud, !imageBackgroud.isEmpty {
            let imagePath = CCUtility.getDirectoryGroup().appendingPathComponent(NCGlobal.shared.appBackground).path + "/" + imageBackgroud
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: imagePath))
                if let image = UIImage(data: data) {
                    backgroundImageView.image = image
                    backgroundImageView.contentMode = .scaleToFill
                    collectionView.backgroundView = backgroundImageView
                }
            } catch { }
        } else {
            backgroundImageView.image = nil
            collectionView.backgroundView = nil
        }

        // COLOR BACKGROUND
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        if traitCollection.userInterfaceStyle == .dark {
            if activeAccount?.darkColorBackground.isEmpty == true {
                collectionView.backgroundColor = NCBrandColor.shared.systemBackground
            } else {
                collectionView.backgroundColor = UIColor(hex: activeAccount?.darkColorBackground ?? "")
            }
        } else {
            if activeAccount?.lightColorBackground.isEmpty == true {
                collectionView.backgroundColor = NCBrandColor.shared.systemBackground
            } else {
                collectionView.backgroundColor = UIColor(hex: activeAccount?.lightColorBackground ?? "")
            }
        }

        collectionView.reloadData()
    }

    @objc func reloadDataSource(_ notification: NSNotification) {

        reloadDataSource()
    }

    @objc func reloadDataSourceNetworkForced(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let serverUrl = userInfo["serverUrl"] as? String {
                if serverUrl == self.serverUrl {
                    reloadDataSourceNetwork(forced: true)
                }
            }
        } else {
            reloadDataSourceNetwork(forced: true)
        }
    }

    @objc func changeStatusFolderE2EE(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func closeRichWorkspaceWebView() {
        reloadDataSourceNetwork()
    }

    // MARK: - Layout

    @objc func setNavigationItem() {

        guard !isEditMode else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "navigationMore"), style: .plain, target: self, action: #selector(tapSelectMenu(sender:)))
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain, target: self, action: #selector(tapSelect(sender:)))
            navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(dataSource.metadatas.count)"
            return
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_select_", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(tapSelect(sender:)))
        navigationItem.leftBarButtonItem = nil
        navigationItem.title = titleCurrentFolder

        // PROFILE BUTTON
        guard let appDelegate = appDelegate, layoutKey == NCGlobal.shared.layoutViewFiles else { return }
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        let image = NCUtility.shared.loadUserImage(for: appDelegate.user, displayName: activeAccount?.displayName, userBaseUrl: appDelegate)

        let button = UIButton(type: .custom)
        button.setImage(image, for: .normal)

        if serverUrl == NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account) {
            if let displayName = activeAccount?.displayName, getNavigationTitle() != activeAccount?.alias {
                button.setTitle("  " + displayName, for: .normal)
            } else {
                button.setTitle("", for: .normal)
            }
            button.setTitleColor(.systemBlue, for: .normal)
        }

        button.semanticContentAttribute = .forceLeftToRight
        button.sizeToFit()
        button.action(for: .touchUpInside) { _ in

            let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
            guard !accounts.isEmpty, let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest
            else { return }

            vcAccountRequest.activeAccount = NCManageDatabase.shared.getActiveAccount()
            vcAccountRequest.accounts = accounts
            vcAccountRequest.enableTimerProgress = false
            vcAccountRequest.enableAddAccount = true
            vcAccountRequest.delegate = self
            vcAccountRequest.dismissDidEnterBackground = true

            let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
            let numberCell = accounts.count + 1
            let height = min(CGFloat(numberCell * Int(vcAccountRequest.heightCell) + 45), screenHeighMax)

            let popup = NCPopupViewController(contentController: vcAccountRequest, popupWidth: 300, popupHeight: height)

            UIApplication.shared.keyWindow?.rootViewController?.present(popup, animated: true)
        }
        navigationItem.setLeftBarButton(UIBarButtonItem(customView: button), animated: true)
        navigationItem.leftItemsSupplementBackButton = true
    }

    func getNavigationTitle() -> String {
        let activeAccount = NCManageDatabase.shared.getActiveAccount()
        guard let userAlias = activeAccount?.alias, !userAlias.isEmpty else {
            return NCBrandOptions.shared.brand
        }
        return userAlias
    }

    // MARK: - TAP EVENT

    @objc func tapSelect(sender: Any) {

        isEditMode = !isEditMode

        selectOcId.removeAll()
        setNavigationItem()

        self.collectionView.reloadData()
    }

    @objc func tapSelectMenu(sender: Any) {
        toggleMenuSelect()
    }

    @objc func longPressCollecationView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        openMenuItems(with: nil, gestureRecognizer: gestureRecognizer)
    }

    // need to be implemented in base class to be overriden
    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) { }
    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) { }
    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) { }
    func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    @available(iOS 13.0, *)
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: { return nil }, actionProvider: { _ in return nil })
    }

    func openMenuItems(with objectId: String?, gestureRecognizer: UILongPressGestureRecognizer) {

        if gestureRecognizer.state != .began { return }

        var listMenuItems: [UIMenuItem] = []
        let touchPoint = gestureRecognizer.location(in: collectionView)

        becomeFirstResponder()

        if !serverUrl.isEmpty {
            listMenuItems.append(UIMenuItem(title: NSLocalizedString("_paste_file_", comment: ""), action: #selector(pasteFilesMenu)))
        }
        if #available(iOS 13.0, *) {
            if !NCBrandOptions.shared.disable_background_color {
                listMenuItems.append(UIMenuItem(title: NSLocalizedString("_background_", comment: ""), action: #selector(backgroundFilesMenu)))
            }
        }

        if !listMenuItems.isEmpty {
            UIMenuController.shared.menuItems = listMenuItems
            UIMenuController.shared.setTargetRect(CGRect(x: touchPoint.x, y: touchPoint.y, width: 0, height: 0), in: collectionView)
            UIMenuController.shared.setMenuVisible(true, animated: true)
        }
    }

    // MARK: - Menu Item

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        if #selector(pasteFilesMenu) == action {
            if !UIPasteboard.general.items.isEmpty {
                return true
            }
        }

        if #selector(backgroundFilesMenu) == action {
            return true
        }

        return false
    }

    @objc func pasteFilesMenu() {
        NCFunctionCenter.shared.pastePasteboard(serverUrl: serverUrl)
    }

    @objc func backgroundFilesMenu() {

        if let vcBackgroundImageColor = UIStoryboard(name: "NCBackgroundImageColor", bundle: nil).instantiateInitialViewController() as? NCBackgroundImageColor {

            vcBackgroundImageColor.delegate = self
            vcBackgroundImageColor.setupColor = collectionView.backgroundColor
            if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
                vcBackgroundImageColor.lightColor = activeAccount.lightColorBackground
                vcBackgroundImageColor.darkColor = activeAccount.darkColorBackground
            }

            let popup = NCPopupViewController(contentController: vcBackgroundImageColor, popupWidth: vcBackgroundImageColor.width, popupHeight: vcBackgroundImageColor.height)
            popup.backgroundAlpha = 0

            self.present(popup, animated: true)
        }
    }

    // MARK: - DataSource + NC Endpoint

    @objc func reloadDataSource() {

        guard let appDelegate = appDelegate, !appDelegate.account.isEmpty else { return }

        // Get richWorkspace Text
        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
        richWorkspaceText = directory?.richWorkspace

        // E2EE
        isEncryptedFolder = CCUtility.isFolderEncrypted(serverUrl, e2eEncrypted: metadataFolder?.e2eEncrypted ?? false, account: appDelegate.account, urlBase: appDelegate.urlBase)

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, account: appDelegate.account)

        // get layout for view
        layoutForView = NCUtility.shared.getLayoutForView(key: layoutKey, serverUrl: serverUrl)
    }

    @objc func reloadDataSourceNetwork(forced: Bool = false) { }

    @objc func networkReadFolder(
        forced: Bool,
        completion: @escaping(
            _ tableDirectory: tableDirectory?,
            _ metadatas: [tableMetadata]?,
            _ metadatasUpdate: [tableMetadata]?,
            _ metadatasDelete: [tableMetadata]?,
            _ errorCode: Int, _ errorDescription: String) -> Void) {

            var tableDirectory: tableDirectory?

            NCNetworking.shared.readFile(serverUrlFileName: serverUrl) { account, metadataFolder, errorCode, errorDescription in

                guard errorCode == 0 else { return completion(nil, nil, nil, nil, errorCode, errorDescription) }

                if let metadataFolder = metadataFolder {
                    tableDirectory = NCManageDatabase.shared.setDirectory(richWorkspace: metadataFolder.richWorkspace, serverUrl: self.serverUrl, account: account)
                }

                guard let appDelegate = self.appDelegate, (forced || tableDirectory?.etag != metadataFolder?.etag || metadataFolder?.e2eEncrypted ?? false)
                else { return completion(tableDirectory, nil, nil, nil, 0, "") }

                NCNetworking.shared.readFolder(serverUrl: self.serverUrl, account: appDelegate.account) { account, metadataFolder, metadatas, metadatasUpdate, _, metadatasDelete, errorCode, errorDescription in

                    guard errorCode == 0 else { return completion(tableDirectory, nil, nil, nil, errorCode, errorDescription) }
                    self.metadataFolder = metadataFolder

                    // E2EE
                    guard let metadataFolder = metadataFolder, metadataFolder.e2eEncrypted && CCUtility.isEnd(toEndEnabled: appDelegate.account)
                    else { return completion(tableDirectory, metadatas, metadatasUpdate, metadatasDelete, errorCode, errorDescription) }

                    NCCommunication.shared.getE2EEMetadata(fileId: metadataFolder.ocId, e2eToken: nil) { account, e2eMetadata, errorCode, errorDescription in

                        if errorCode == 0 && e2eMetadata != nil {
                            if !NCEndToEndMetadata.shared.decoderMetadata(e2eMetadata!, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: self.serverUrl, account: account, urlBase: appDelegate.urlBase) {

                                NCContentPresenter.shared.messageNotification(
                                    "_error_e2ee_", description: "_e2e_error_decode_metadata_",
                                    delay: NCGlobal.shared.dismissAfterSecond,
                                    type: NCContentPresenter.messageType.error,
                                    errorCode: NCGlobal.shared.errorDecodeMetadata)
                            } else {
                                self.reloadDataSource()
                            }

                        } else if errorCode != NCGlobal.shared.errorResourceNotFound {
                            NCContentPresenter.shared.messageNotification(
                                "_error_e2ee_", description: "_e2e_error_decode_metadata_",
                                delay: NCGlobal.shared.dismissAfterSecond,
                                type: NCContentPresenter.messageType.error,
                                errorCode: NCGlobal.shared.errorDecodeMetadata)
                        }

                        completion(tableDirectory, metadatas, metadatasUpdate, metadatasDelete, errorCode, errorDescription)
                    }
                }
            }
        }

    // MARK: - Push metadata

    func pushMetadata(_ metadata: tableMetadata) {

        guard let serverUrlPush = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), !pushed else { return }
        appDelegate?.activeMetadata = metadata
        if let viewController = appDelegate?.getVCForLayoutKey(layoutKey: layoutKey, serverUrlPush: serverUrlPush) {
            return pushViewController(viewController: viewController, onlyIfLoaded: true)
        }

        switch layoutKey {
            // FILES
        case NCGlobal.shared.layoutViewFiles:
            guard let viewController = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles else { return }

                viewController.isRoot = false
                viewController.serverUrl = serverUrlPush
                viewController.titleCurrentFolder = metadata.fileNameView

                appDelegate?.listFilesVC[serverUrlPush] = viewController

                pushViewController(viewController: viewController)
        case NCGlobal.shared.layoutViewFavorite:
            guard let viewController = UIStoryboard(name: "NCFavorite", bundle: nil).instantiateInitialViewController() as? NCFavorite else { return }

                viewController.serverUrl = serverUrlPush
                viewController.titleCurrentFolder = metadata.fileNameView

                appDelegate?.listFavoriteVC[serverUrlPush] = viewController
                pushViewController(viewController: viewController)
        case NCGlobal.shared.layoutViewOffline:
            guard let viewController = UIStoryboard(name: "NCOffline", bundle: nil).instantiateInitialViewController() as? NCOffline else { return }

                viewController.serverUrl = serverUrlPush
                viewController.titleCurrentFolder = metadata.fileNameView

                appDelegate?.listOfflineVC[serverUrlPush] = viewController

                pushViewController(viewController: viewController)
        case NCGlobal.shared.layoutViewRecent:
            guard let viewController = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles else { return }

                viewController.isRoot = false
                viewController.serverUrl = serverUrlPush
                viewController.titleCurrentFolder = metadata.fileNameView

                appDelegate?.listFilesVC[serverUrlPush] = viewController

                pushViewController(viewController: viewController)
        case NCGlobal.shared.layoutViewShares:
            guard let viewController = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles else { return }

            viewController.isRoot = false
            viewController.serverUrl = serverUrlPush
            viewController.titleCurrentFolder = metadata.fileNameView

            appDelegate?.listFilesVC[serverUrlPush] = viewController

            pushViewController(viewController: viewController)
        case NCGlobal.shared.layoutViewViewInFolder:
            guard let viewController = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as? NCFileViewInFolder else { return }
            viewController.serverUrl = serverUrlPush
            viewController.titleCurrentFolder = metadata.fileNameView
            pushViewController(viewController: viewController)
        default:
            break
        }
    }
}
