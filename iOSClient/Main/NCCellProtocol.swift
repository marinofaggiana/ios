//
//  NCCellProtocol.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 05.06.20.
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

@objc protocol NCCellProtocol {
    var fileAvatarImageView: UIImageView? { get }
    var filePreviewImageView: UIImageView? { get }
    var fileObjectId: String? { get set }
    var fileUser: String? { get set }
}

protocol NCMetadataCell: NCCellProtocol {
    var imageItem: UIImageView! { get set }
    var imageSelect: UIImageView! { get set }
    var imageStatus: UIImageView! { get set }
    var imageFavorite: UIImageView! { get set }
    var imageLocal: UIImageView! { get set }
    var labelTitle: UILabel! { get set }
    var buttonMore: UIButton! { get set }
    var progressView: UIProgressView! { get set }

    func setButtonMore(named: String, image: UIImage)
    func selectMode(_ status: Bool)
    func selected(_ status: Bool)
}

extension NCMetadataCell {
    func resetUI(for metadata: tableMetadata) {
        fileObjectId = metadata.ocId
        fileUser = metadata.ownerId
        labelTitle.textColor = NCBrandColor.shared.label
        labelTitle.text = metadata.fileNameView

        imageSelect.image = nil
        imageStatus.image = nil
        imageLocal.image = nil
        imageFavorite.image = nil
        imageItem.image = nil
        imageItem.backgroundColor = nil
    }
}
