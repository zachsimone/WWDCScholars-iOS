//
//  ScreenshotsTableViewCell.swift
//  WWDCScholars
//
//  Created by Andrew Walker on 17/04/2016.
//  Copyright © 2016 WWDCScholars. All rights reserved.
//

import UIKit

class ScreenshotsTableViewCell: UITableViewCell, UICollectionViewDelegate {
    @IBOutlet private weak var collectionView: UICollectionView!
    
    var screenshots: [UIImage] = []
    
    override func awakeFromNib() {
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
    }
}

// MARK: - UICollectionViewDataSource

extension ScreenshotsTableViewCell: UICollectionViewDataSource {
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.screenshots.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("screenshotsCollectionViewCell", forIndexPath: indexPath) as! ScreenshotsCollectionViewCell
        
        cell.imageView.image = self.screenshots[indexPath.item]
        
        return cell
    }
}