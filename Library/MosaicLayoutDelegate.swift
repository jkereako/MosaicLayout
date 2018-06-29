//
//  MosaicLayoutDelegate.swift
//  MosaicLayout
//
//  Created by Jeffrey Kereakoglow on 3/10/16.
//  Copyright © 2016 Alexis Digital. All rights reserved.
//

import UIKit

public protocol MosaicLayoutDelegate: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                        sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize

    func collectionView(_ cv: UICollectionView,
                        layout: UICollectionViewLayout,
                        insetsForItemAtIndexPath indexPath: IndexPath) -> UIEdgeInsets
}
