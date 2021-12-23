//
//  NCCollectionCommon+DataSource.swift
//  Nextcloud
//
//  Created by Henrik Storch on 23.12.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit
import NCCommunication

// MARK: - Collection View

extension NCCollectionViewCommon: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        if kind == UICollectionView.elementKindSectionHeader {

            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as? NCSectionHeaderMenu else { return UICollectionReusableView() }
            self.header = header

            if collectionView.collectionViewLayout == gridLayout {
                header.buttonSwitch.setImage(UIImage(named: "switchList")!.image(color: NCBrandColor.shared.gray, size: 50), for: .normal)
            } else {
                header.buttonSwitch.setImage(UIImage(named: "switchGrid")!.image(color: NCBrandColor.shared.gray, size: 50), for: .normal)
            }

            header.delegate = self
            header.setStatusButton(count: dataSource.metadatas.count)
            header.setTitleSorted(datasourceTitleButton: layoutForView?.titleButtonHeader ?? "")
            header.viewRichWorkspaceHeightConstraint.constant = headerRichWorkspaceHeight
            header.setRichWorkspaceText(richWorkspaceText: richWorkspaceText)

            return header

        } else {
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter else { return UICollectionReusableView() }
            let info = dataSource.getFilesInformation()
            footer.setTitleLabel(directories: info.directories, files: info.files, size: info.size )

            return footer
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath), let cell = cell as? NCCellProtocol else { return }

        // Thumbnail
        if !metadata.directory {
            if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                cell.filePreviewImageView?.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            } else {
                NCOperationQueue.shared.downloadThumbnail(metadata: metadata, placeholder: true, cell: cell, view: collectionView)
            }
        }

        // Avatar
        if metadata.ownerId.count > 0,
           metadata.ownerId != appDelegate?.userId,
           appDelegate?.account == metadata.account {
            let fileName = metadata.userBaseUrl + "-" + metadata.ownerId + ".png"
            NCOperationQueue.shared.downloadAvatar(user: metadata.ownerId, dispalyName: metadata.ownerDisplayName, fileName: fileName, cell: cell, view: collectionView)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberItems = dataSource.numberOfItems()
        emptyDataSet?.numberOfItemsInSection(numberItems, section: section)
        return numberItems
    }

    //
    // LAYOUT LIST
    //
    func makeListCell(for indexPath: IndexPath, metadata: tableMetadata, tableShare: tableShare?) -> UICollectionViewCell {
        guard let appDelegate = appDelegate, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell
        else { return UICollectionViewCell() }
        let (isShare, _) = NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata, metadataFolder: metadataFolder)

        cell.delegate = self

        setupCellUI(cell, for: metadata, tableShare: tableShare)

        if isSearching {
            cell.labelTitle.text = NCUtilityFileSystem.shared.getPath(metadata: metadata)
            cell.labelTitle.lineBreakMode = .byTruncatingHead
        } else {
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.lineBreakMode = .byTruncatingMiddle
        }
        cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)
        cell.labelInfo.textColor = NCBrandColor.shared.systemGray

        // Progress
        var totalBytes: Int64 = 0
        if let progressType = appDelegate.listProgress[metadata.ocId] {
            totalBytes = progressType.totalBytes
        }

        // Share image
        if isShare {
            cell.imageShared.image = NCBrandColor.cacheImages.shared
        } else if tableShare != nil && tableShare?.shareType == 3 {
            cell.imageShared.image = NCBrandColor.cacheImages.shareByLink
        } else if tableShare != nil && tableShare?.shareType != 3 {
            cell.imageShared.image = NCBrandColor.cacheImages.shared
        } else {
            cell.imageShared.image = NCBrandColor.cacheImages.canShare
        }
        if appDelegate.account != metadata.account {
            cell.imageShared.image = NCBrandColor.cacheImages.shared
        }

        // Write status on Label Info
        switch metadata.status {
        case NCGlobal.shared.metadataStatusWaitDownload:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_download_", comment: "")
        case NCGlobal.shared.metadataStatusInDownload:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_download_", comment: "")
        case NCGlobal.shared.metadataStatusDownloading:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - ↓ " + CCUtility.transformedSize(totalBytes)
        case NCGlobal.shared.metadataStatusWaitUpload:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_upload_", comment: "")
        case NCGlobal.shared.metadataStatusInUpload:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_upload_", comment: "")
        case NCGlobal.shared.metadataStatusUploading:
            cell.labelInfo.text = CCUtility.transformedSize(metadata.size) + " - ↑ " + CCUtility.transformedSize(totalBytes)
        case NCGlobal.shared.metadataStatusUploadError:
            if !metadata.sessionError.isEmpty {
                cell.labelInfo.text = NSLocalizedString("_status_wait_upload_", comment: "") + " " + metadata.sessionError
            } else {
                cell.labelInfo.text = NSLocalizedString("_status_wait_upload_", comment: "")
            }
        default:
            break
        }

        // E2EE
        cell.hideButtonShare(metadata.e2eEncrypted || isEncryptedFolder)

        // Remove last separator
        if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
            cell.separator.isHidden = true
        } else {
            cell.separator.isHidden = false
        }

        // Disable Share Button
        if appDelegate.disableSharesView == true {
            cell.hideButtonShare(true)
        }

        return cell
    }

    //
    // LAYOUT GRID
    //
    func makeGridCell(for indexPath: IndexPath, metadata: tableMetadata, tableShare: tableShare?) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell
        else { return UICollectionViewCell() }
        cell.delegate = self
        setupCellUI(cell, for: metadata, tableShare: tableShare)
        return cell

    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else {
            if layoutForView?.layout == NCGlobal.shared.layoutList, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as? NCListCell {
                return cell
            } else if layoutForView?.layout == NCGlobal.shared.layoutGrid, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridCell {
                return cell
            } else { return UICollectionViewCell() }
        }

        let tableShare = dataSource.metadataShare[metadata.ocId]

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            return makeListCell(for: indexPath, metadata: metadata, tableShare: tableShare)
        } else if layoutForView?.layout == NCGlobal.shared.layoutGrid {
            return makeGridCell(for: indexPath, metadata: metadata, tableShare: tableShare)
        }

        return UICollectionViewCell()
    }

    func setupCellUI(_ cell: NCMetadataCell, for metadata: tableMetadata, tableShare: tableShare?) {
        guard let appDelegate = appDelegate else { return }

        cell.fileObjectId = metadata.ocId
        cell.fileUser = metadata.ownerId
        cell.labelTitle.textColor = NCBrandColor.shared.label
        cell.labelTitle.text = metadata.fileNameView

        cell.imageSelect.image = nil
        cell.imageStatus.image = nil
        cell.imageLocal.image = nil
        cell.imageFavorite.image = nil
        cell.imageItem.image = nil
        cell.imageItem.backgroundColor = nil

        // Progress
        var progress: Float = 0.0
        if let progressType = appDelegate.listProgress[metadata.ocId] {
            progress = progressType.progress
        }

        if metadata.status == NCGlobal.shared.metadataStatusDownloading || metadata.status == NCGlobal.shared.metadataStatusUploading {
            cell.progressView.isHidden = false
            cell.progressView.progress = progress
        } else {
            cell.progressView.isHidden = true
            cell.progressView.progress = 0.0
        }

        if metadata.directory {
            let (isShare, isMounted) = NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata, metadataFolder: metadataFolder)

            if metadata.e2eEncrypted {
                cell.imageItem.image = NCBrandColor.cacheImages.folderEncrypted
            } else if isShare {
                cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
            } else if tableShare != nil && tableShare?.shareType != 3 {
                cell.imageItem.image = NCBrandColor.cacheImages.folderSharedWithMe
            } else if tableShare != nil && tableShare?.shareType == 3 {
                cell.imageItem.image = NCBrandColor.cacheImages.folderPublic
            } else if metadata.mountType == "group" {
                cell.imageItem.image = NCBrandColor.cacheImages.folderGroup
            } else if isMounted {
                cell.imageItem.image = NCBrandColor.cacheImages.folderExternal
            } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
                cell.imageItem.image = NCBrandColor.cacheImages.folderAutomaticUpload
            } else {
                cell.imageItem.image = NCBrandColor.cacheImages.folder
            }

            let lockServerUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
            let tableDirectory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, lockServerUrl))

            // Local image: offline
            if tableDirectory != nil && tableDirectory!.offline {
                cell.imageLocal.image = NCBrandColor.cacheImages.offlineFlag
            }

        } else {

            // image Local
            if dataSource.metadataOffLine.contains(metadata.ocId) {
                cell.imageLocal.image = NCBrandColor.cacheImages.offlineFlag
            } else if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                cell.imageLocal.image = NCBrandColor.cacheImages.local
            }
        }

        // image Favorite
        if metadata.favorite {
            cell.imageFavorite.image = NCBrandColor.cacheImages.favorite
        }

        if metadata.status == NCGlobal.shared.metadataStatusInDownload
            || metadata.status == NCGlobal.shared.metadataStatusDownloading
            || metadata.status == NCGlobal.shared.metadataStatusInUpload
            || metadata.status == NCGlobal.shared.metadataStatusUploading {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreStop, image: NCBrandColor.cacheImages.buttonStop)
        } else {
            cell.setButtonMore(named: NCGlobal.shared.buttonMoreMore, image: NCBrandColor.cacheImages.buttonMore)
        }

        // Live Photo
        if metadata.livePhoto {
            cell.imageStatus.image = NCBrandColor.cacheImages.livePhoto
        }

        // Edit mode
        if isEditMode {
            cell.selectMode(true)
            if selectOcId.contains(metadata.ocId) {
                cell.selected(true)
            } else {
                cell.selected(false)
            }
        } else {
            cell.selectMode(false)
        }
    }
}

extension NCCollectionViewCommon: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return }
        appDelegate?.activeMetadata = metadata

        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            self.navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(dataSource.metadatas.count)"
            return
        }

        if metadata.e2eEncrypted && !CCUtility.isEnd(toEndEnabled: appDelegate?.account) {
            NCContentPresenter.shared.messageNotification("_info_", description: "_e2e_goto_settings_for_enable_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorE2EENotEnabled)
            return
        }

        if metadata.directory {

            pushMetadata(metadata)

        } else if !(self is NCFileViewInFolder) {

            let imageIcon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))

            if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
                var metadatas: [tableMetadata] = []
                for metadata in dataSource.metadatas {
                    if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
                        metadatas.append(metadata)
                    }
                }
                NCViewer.shared.view(viewController: self, metadata: metadata, metadatas: metadatas, imageIcon: imageIcon)
                return
            }

            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                NCViewer.shared.view(viewController: self, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon)
            } else if NCCommunication.shared.isNetworkReachable() {
                NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileView) { _ in }
            } else {
                NCContentPresenter.shared.messageNotification("_info_", description: "_go_online_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorOffline)
            }
        }
    }

    func pushViewController(viewController: UIViewController, onlyIfLoaded: Bool = false) {
        guard !pushed else { return }
        if onlyIfLoaded, !viewController.isViewLoaded { return }
        pushed = true
        navigationController?.pushViewController(viewController, animated: true)
    }

    func collectionViewSelectAll() {
        selectOcId = dataSource.metadatas.map({ $0.ocId })
        navigationItem.title = NSLocalizedString("_selected_", comment: "") + " : \(selectOcId.count)" + " / \(dataSource.metadatas.count)"
        collectionView.reloadData()
    }

    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        if isEditMode || collectionView.cellForItem(at: indexPath) is NCTransferCell { return nil }
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return nil }
        let identifier = indexPath as NSCopying
        var image: UIImage?
        let cell = collectionView.cellForItem(at: indexPath)
        if let cell = cell as? NCListCell {
            image = cell.imageItem.image
        } else if let cell = cell as? NCGridCell {
            image = cell.imageItem.image
        }

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image)
        }, actionProvider: { _ in
            return NCFunctionCenter.shared.contextMenuConfiguration(ocId: metadata.ocId, viewController: self, enableDeleteLocal: true, enableViewInFolder: false, image: image)
        })
    }

    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion {
            if let indexPath = configuration.identifier as? IndexPath {
                self.collectionView(collectionView, didSelectItemAt: indexPath)
            }
        }
    }
}
