//
//  NCCollectionCommon+Search.swift
//  Nextcloud
//
//  Created by Henrik Storch on 23.12.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
}
