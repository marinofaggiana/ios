//
//  NCCollectionCommon+Search.swift
//  Nextcloud
//
//  Created by Henrik Storch on 23.12.21.
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

// MARK: - SEARCH
extension NCCollectionViewCommon: UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {

    func updateSearchResults(for searchController: UISearchController) {
        timerInputSearch?.invalidate()
        timerInputSearch = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(reloadDataSourceNetwork), userInfo: nil, repeats: false)
        literalSearch = searchController.searchBar.text
        collectionView?.reloadData()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isSearching = true
        metadatasSource.removeAll()
        reloadDataSource()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        isSearching = false
        literalSearch = ""
        reloadDataSource()
    }

    @objc func networkSearch() {
        guard let appDelegate = appDelegate, !appDelegate.account.isEmpty, let literalSearch = literalSearch, !literalSearch.isEmpty else {
            DispatchQueue.main.async { self.refreshControl.endRefreshing() }
            return
        }
        let completionHandler: ([tableMetadata]?, Int, String) -> Void = { metadatas, errorCode, _ in
            DispatchQueue.main.async {
                if self.searchController?.isActive == true, errorCode == 0, let metadatas = metadatas {
                    self.metadatasSource = metadatas
                }
                self.refreshControl.endRefreshing()
                self.isReloadDataSourceNetworkInProgress = false
                self.reloadDataSource()
            }
        }

        isReloadDataSourceNetworkInProgress = true
        collectionView?.reloadData()

        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        if serverVersionMajor >= NCGlobal.shared.nextcloudVersion20 {
            NCNetworking.shared.unifiedSearchFiles(urlBase: appDelegate, literal: literalSearch, update: { metadatas in
                guard let metadatas = metadatas else { return }
                self.metadatasSource = Array(metadatas)
                self.reloadDataSource()
            }, completion: completionHandler)
        } else {
            NCNetworking.shared.searchFiles(urlBase: appDelegate, literal: literalSearch, completion: completionHandler)
        }
    }
}
