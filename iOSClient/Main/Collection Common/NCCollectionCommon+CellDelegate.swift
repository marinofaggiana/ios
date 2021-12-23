//
//  NCCollectionCommon+CellDelegate.swift
//  Nextcloud
//
//  Created by Henrik Storch on 23.12.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

extension NCCollectionViewCommon: NCListCellDelegate, NCGridCellDelegate {
    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {
        tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, image: image, sender: sender)
    }

    func tapShareListItem(with objectId: String, sender: Any) {
        if isEditMode { return }
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }
        NCFunctionCenter.shared.openShare(viewController: self, metadata: metadata, indexPage: .sharing)
    }

    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {

        if isEditMode { return }

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId) else { return }

        if namedButtonMore == NCGlobal.shared.buttonMoreMore {
            toggleMenu(metadata: metadata, imageIcon: image)
        } else if namedButtonMore == NCGlobal.shared.buttonMoreStop {
            NCNetworking.shared.cancelTransferMetadata(metadata) { }
        }
    }
}
