//
//  ViewModel.swift
//  MosaicLayout
//
//  Created by Jeffrey Kereakoglow on 12/11/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

protocol ViewControllerDelegate: class {
  func configureCell(cell: UICollectionViewCell, withObject object: AnyObject)
}

class ViewModel: NSObject {
  weak var delegate: ViewControllerDelegate?

  private var numbers:[UInt]
  private var cellWidths:[UInt]
  private var cellHeights:[UInt]
  private var randomInteger: UInt {
    get {
      let random = arc4random_uniform(6) + 1

      switch random {
      case 0, 1, 2:
        return 1

      case 5:
        return 3

      default:
        return 2

      }
    }
  }

  override init() {
    numbers = [UInt]()
    cellWidths = [UInt]()
    cellHeights = [UInt]()

    super.init()

    refreshData()
  }

  func refreshData() {
    // Reset the properties
    numbers = [UInt]()
    cellWidths = [UInt]()
    cellHeights = [UInt]()

    // Assign new values
    for i in 0...15 {
      numbers.append(UInt(i))
      cellWidths.append(randomInteger)
      cellHeights.append(randomInteger)
    }
  }

  func collectionView(cv: UICollectionView, addIndexPath indexPath: NSIndexPath, completion: (Void) -> Void ) {
    guard indexPath.row < numbers.count else {
      return
    }

    cv.performBatchUpdates({[unowned self] in
      let index = indexPath.row

      self.numbers.insert(UInt(self.numbers.count + 1), atIndex: index)
      self.cellWidths.insert(self.randomInteger, atIndex: index)
      self.cellHeights.insert(self.randomInteger, atIndex: index)

      cv.insertItemsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)])

      },
      completion: { (let done: Bool) in completion() }
    )
  }

  func collectionView(cv: UICollectionView, removeIndexPath indexPath: NSIndexPath, completion: (Void) -> Void) {
    guard numbers.count > 0 && indexPath.row < numbers.count else {
      return
    }

    cv.performBatchUpdates({[unowned self] in
      let index = indexPath.row

      self.numbers.removeAtIndex(index)
      self.cellWidths.removeAtIndex(index)
      self.cellHeights.removeAtIndex(index)

      cv.deleteItemsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)])


      },
      completion: { (let done: Bool) in completion() })
  }
}

// MARK:- UICollectionViewDataSource
extension ViewModel: UICollectionViewDataSource {
  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return numbers.count
  }

  func collectionView(collectionView: UICollectionView,
    cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
      let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath)

      delegate?.configureCell(cell, withObject: numbers[indexPath.row])

      return cell
  }
}

// MARK:- MosaicLayoutDelegate
extension ViewModel: MosaicLayoutDelegate {
  func collectionView(cv: UICollectionView, layout: UICollectionViewLayout,
    sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {

      assert(indexPath.row <= numbers.count)

      return CGSizeMake(CGFloat(cellWidths[indexPath.row]), CGFloat(cellHeights[indexPath.row]))
  }

  func collectionView(cv: UICollectionView,
    layout: UICollectionViewLayout,
    insetsForItemAtIndexPath indexPath: NSIndexPath) -> UIEdgeInsets {
      
      return UIEdgeInsetsMake(1.0, 1.0, 1.0, 1.0)
  }
}
