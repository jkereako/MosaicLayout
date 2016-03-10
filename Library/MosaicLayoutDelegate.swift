//
//  MosaicLayoutDelegate.swift
//  MosaicLayout
//
//  Created by Jeffrey Kereakoglow on 3/10/16.
//  Copyright © 2016 Alexis Digital. All rights reserved.
//

import UIKit

protocol MosaicLayoutDelegate: UICollectionViewDelegate {
  func collectionView(cv: UICollectionView, layout: UICollectionViewLayout,
    sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize

  func collectionView(cv: UICollectionView,
    layout: UICollectionViewLayout,
    insetsForItemAtIndexPath indexPath: NSIndexPath) -> UIEdgeInsets
}
