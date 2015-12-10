//
//  MosaicLayout.swift
//  MosaicLayout
//
//  Created by Jeffrey Kereakoglow on 12/10/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

protocol MosaicLayoutDelegate: UICollectionViewDelegate {
  func collectionView(cv: UICollectionView, layout: UICollectionViewLayout,
    sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize

  func collectionView(cv: UICollectionView,
    layout: UICollectionViewLayout,
    insetsForItemAtIndexPath indexPath: NSIndexPath) -> UIEdgeInsets

}

class MosaicLayout: UICollectionViewLayout {
  //-- Interface
  weak var delegate: MosaicLayoutDelegate?
  let scrollDirection: UICollectionViewScrollDirection
  let preemptivelyRenderLayout: Bool
  let cellSize: CGSize

  //-- things
  var firstOpenSpace: CGPoint
  // This is a map of integers to dictionaries of integers mapped to index paths
  var indexPathByPosition: [UInt: [UInt: NSIndexPath]]
  var positionByIndexPath: [UInt: [UInt: NSValue]]

  //-- Caching
  // The variables below are used for caching to prevent too much work.
  var layoutAttributesCache: [UICollectionViewLayoutAttributes]
  var layoutRectCache: CGRect
  var indexPathCache: NSIndexPath

  var maximumNumberOfCellsInBounds: UInt {

    guard let cv = collectionView else {
      // This will never happen, but collection view is an optional, so we have to unwrap it.
      return 0
    }

    var size: UInt = 0;
    let contentRect = UIEdgeInsetsInsetRect(cv.frame, cv.contentInset)

    switch scrollDirection {
    case .Vertical:
      size = UInt(CGRectGetWidth(contentRect) / cellSize.width)
    case .Horizontal:
      size = UInt(CGRectGetWidth(contentRect) / cellSize.height)
    }

    if size == 0 {
      print("Cannot fit cell in contect rect. Defaulting to 1")
      return 1
    }

    return size
  }

  override init() {
    scrollDirection = .Vertical
    preemptivelyRenderLayout = false
    cellSize = CGSizeMake(100.0, 100.0)
    layoutAttributesCache = [UICollectionViewLayoutAttributes]()
    layoutRectCache = CGRectZero
    indexPathCache = NSIndexPath()

    super.init()
  }

  required init?(coder aDecoder: NSCoder) {
    scrollDirection = .Vertical
    preemptivelyRenderLayout = false
    cellSize = CGSizeMake(100.0, 100.0)
    layoutAttributesCache = [UICollectionViewLayoutAttributes]()
    layoutRectCache = CGRectZero
    indexPathCache = NSIndexPath()

    super.init(coder: aDecoder)
  }

  override func prepareLayout() {
    super.prepareLayout()

    guard delegate != nil, let cv = collectionView else {
      return
    }

    let scrollFrame = CGRectMake(
      cv.contentOffset.x, cv.contentOffset.y, cv.frame.size.width, cv.frame.size.height)

    let unboundIndex: UInt
    switch scrollDirection {
    case .Vertical:
      unboundIndex = UInt((CGRectGetMaxY(scrollFrame) / cellSize.height) + 1)

    case .Horizontal:
      unboundIndex = UInt((CGRectGetMaxY(scrollFrame) / cellSize.width) + 1)
    }

    if (preemptivelyRenderLayout) {
      ;
    }

    else {
      ;
    }
  }
}

// MARK:- Getters
extension MosaicLayout {
  private func rectForIndexPath(indexPath: NSIndexPath) -> CGRect {
    guard let cv = collectionView else {
      return CGRectZero
    }

    let position = positionForIndexPath(indexPath)
    let aCellSize = sizeForCellAtIndexPath(indexPath)
    var padding: CGFloat = 0.0
    let contentRect = UIEdgeInsetsInsetRect(cv.frame, cv.contentInset)
    let result: CGRect

    switch scrollDirection {
    case .Vertical:
      let width = CGRectGetWidth(contentRect)
      padding = (width - CGFloat(maximumNumberOfCellsInBounds) * cellSize.width) / 2
      result = CGRectMake(
        position.x * cellSize.width + padding,
        position.y * cellSize.height,
        aCellSize.width * cellSize.width,
        aCellSize.height * cellSize.height
      )

    case .Horizontal:
      let height = CGRectGetHeight(contentRect)
      padding = (height - CGFloat(maximumNumberOfCellsInBounds) * cellSize.height) / 2
      result = CGRectMake(
        position.x * cellSize.width,
        position.y * cellSize.height + padding,
        aCellSize.width * cellSize.width,
        aCellSize.height * cellSize.height
      )
    }

    return result
  }

  private func sizeForCellAtIndexPath(indexPath: NSIndexPath) -> CGSize {
    if let cv = collectionView, let d = delegate {
      if d.respondsToSelector("collectionView:layout:sizeForItemAtIndexPath:") {
        return d.collectionView(cv, layout: self, sizeForItemAtIndexPath: indexPath)
      }
    }

    return CGSizeMake(1.0, 1.0)
    
  }

  private func positionForIndexPath(indexPath: NSIndexPath) -> CGPoint {

    // Check if the cell has a position, else make a new position
    guard let section = positionByIndexPath[UInt(indexPath.section)],
      let row = section[UInt(indexPath.row)] else {
        insertCellsToIndexPath(indexPath)
    }

    return row.CGPointValue()
  }

  private func indexPathForPosition(position: CGPoint) -> NSIndexPath? {
    let unboundIndex, boundIndex: UInt

    switch scrollDirection {
    case .Vertical:
      unboundIndex = UInt(position.y)
      boundIndex = UInt(position.x)

    case .Horizontal:
      unboundIndex = UInt(position.x)
      boundIndex = UInt(position.y)
    }

    return indexPathByPosition[boundIndex]?[unboundIndex]
  }
}

// MARK:- Cell insertion
extension MosaicLayout {
  private func insertCellAtIndexPath(indexPath: NSIndexPath) -> Bool {
    return true;
  }

  private func insertCellsToIndexPath(indexPath: NSIndexPath) {
    guard let cv = collectionView else {
      return
    }

    let sectionCount = cv.numberOfSections()
    var section = 0
    var row = 0

    for section = indexPathCache.section; section < sectionCount; section++ {
      let rowCount = cv.numberOfItemsInSection(section)

      for row = indexPathCache.row + 1; row < rowCount; row++ {

        // Return if we are past the desired row
        if section >= indexPath.section && row > indexPath.row {
          return
        }

        let newIndexPath = NSIndexPath(forItem: row, inSection: section)

        if insertCellAtIndexPath(indexPath) {
          indexPathCache = newIndexPath
        }
      }
    }
  }

  private func insertCellsToUnboundIndex(unboundIndex: UInt) {
    let sectionCount = collectionView?.numberOfSections() ?? 0

    //for var aRow = row + 1; row < rows; ++aRow
    for var section = indexPathCache.section; section < sectionCount; section++ {
      let rowCount = collectionView?.numberOfItemsInSection(section) ?? 0

      for var row = indexPathCache.row + 1; row < rowCount; row++ {
        let indexPath = NSIndexPath(forRow: row, inSection: section)

        if insertCellAtIndexPath(indexPath) {
          indexPathCache = indexPath
        }

        // Test whether we are beyond the unbound index.
        switch scrollDirection {
        case .Vertical:
          if UInt(firstOpenSpace.y) >= unboundIndex {
            return
          }

          break

        case .Horizontal:
          if UInt(firstOpenSpace.x) >= unboundIndex {
            return
          }

          break

        }
      }
    }
  }
}

//MARK:- Cell traversal
extension MosaicLayout {
  private func traverseCellsBetweenBounds(start start: UInt, end: UInt, closure: (point: CGPoint) -> Bool) -> Bool {
    var boundIndex, unboundIndex: UInt

    // O(n^2)
    for unboundIndex = start; unboundIndex < end; unboundIndex++ {
      for boundIndex = 0; boundIndex < maximumNumberOfCellsInBounds; boundIndex++ {
        var point: CGPoint

        switch scrollDirection {
        case .Vertical:
          point = CGPointMake(CGFloat(boundIndex), CGFloat(unboundIndex))
        case .Horizontal:
          point = CGPointMake(CGFloat(unboundIndex), CGFloat(boundIndex))
        }

        if !closure(point: point) {
          return false
        }
      }
    }

    return true
  }
  /*
  - (BOOL)traverseCellsBetweenBounds:(NSUInteger)start and:(NSUInteger)end block:(BOOL(^)(CGPoint))block {
  NSUInteger unbound = 0;
  NSUInteger bounds = 0;

  for(unbound = start; unbound < end; unbound++) {
  for(bounds = 0; bounds < self.maximumNumberOfItemsInBounds; bounds++) {

  CGPoint point = CGPointZero;

  switch (self.scrollDirection) {
  case UICollectionViewScrollDirectionVertical:
  point = CGPointMake(bounds, unbound);
  break;

  case UICollectionViewScrollDirectionHorizontal:
  point = CGPointMake(unbound, bounds);
  break;
  }

  if(!block(point)) {
  return NO;
  }
  }
  }

  return YES;
  }
*/
  private func traverseOpenCells(closure: (point: CGPoint) -> Bool) -> Bool {
    var allTakenBefore = true
    var unboundIndex: UInt

    switch scrollDirection {
    case .Vertical:
      unboundIndex = UInt(firstOpenSpace.y)

    case .Horizontal:
      unboundIndex = UInt(firstOpenSpace.x)
    }

    repeat {
      var boundIndex: UInt

      for boundIndex = 0; boundIndex < maximumNumberOfCellsInBounds; boundIndex++ {
        var point: CGPoint

        switch scrollDirection {
        case .Vertical:
          point = CGPointMake(CGFloat(boundIndex), CGFloat(unboundIndex))

        case .Horizontal:
          point = CGPointMake(CGFloat(unboundIndex), CGFloat(boundIndex))
        }


        if indexPathForPosition(point) != nil {
          continue
        }

        if allTakenBefore {
          firstOpenSpace = point
          allTakenBefore = false
        }

        if !closure(point: point) {
          // break
          return false
        }
      }

      unboundIndex++

    } while(true)

    assertionFailure("Unable to find insertion point for cell")

    return true

  }
  private func traverseCellsForPosition(point: CGPoint, withSize size: CGSize, closure: (point: CGPoint) -> Bool) -> Bool {
    var column: UInt = 0
    var row: UInt = 0

    // O(n^2)
    for column = UInt(point.x); column < UInt(point.x + size.width); column++ {
      for row = UInt(point.y); row < UInt(point.y + size.height); column++ {
        if !closure(point: CGPointMake(CGFloat(column), CGFloat(row))) {
          return false
        }
      }
    }

    return true
  }

  /*
  - (BOOL)traverseCellsForPosition:(CGPoint)point withSize:(CGSize)size block:(BOOL(^)(CGPoint))block {
  NSUInteger column = 0;
  NSUInteger row = 0;

  for(column = (NSUInteger)point.x; column < point.x + size.width; column++) {
  for (row = (NSUInteger)point.y; row < point.y + size.height; row++) {

  if(!block(CGPointMake(column, row))) {
  // Terminate iteration
  return NO;
  }
  }
  }
  return YES;
  }
*/
}
