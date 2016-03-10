//
//  MosaicLayout.swift
//  MosaicLayout
//
//  Created by Jeffrey Kereakoglow on 12/10/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

class MosaicLayout: UICollectionViewLayout {
  //-- Interface
  weak var delegate: MosaicLayoutDelegate?

  var preemptivelyRenderLayout: Bool
  var scrollDirection: UICollectionViewScrollDirection {
    didSet {
      invalidateLayout()
    }
  }

  var cellSize: CGSize {
    didSet {
      invalidateLayout()
    }
  }

  //-- things
  var firstOpenSpace: CGPoint
  var furthestCellPosition: CGPoint {
    didSet {
      // Allow the property to be reset to zero
      if furthestCellPosition != CGPointZero {
        furthestCellPosition = CGPoint(
          x: max(furthestCellPosition.x, oldValue.x),
          y: max(furthestCellPosition.y, oldValue.y)
        )
      }
    }
  }

  // This is a map of integers to dictionaries of integers mapped to index paths
  var indexPathByPosition: [Int: [Int: NSIndexPath]]
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
      size = UInt(CGRectGetHeight(contentRect) / cellSize.height)
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
    cellSize = CGSize(width: 100.0, height: 100.0)
    layoutAttributesCache = [UICollectionViewLayoutAttributes]()
    layoutRectCache = CGRectZero
    indexPathCache = NSIndexPath(forRow: 0, inSection: 0)
    firstOpenSpace = CGPointZero
    furthestCellPosition = CGPointZero
    indexPathByPosition = [Int: [Int: NSIndexPath]]()
    positionByIndexPath = [UInt: [UInt: NSValue]]()

    super.init()
  }

  required init?(coder aDecoder: NSCoder) {
    scrollDirection = .Vertical
    preemptivelyRenderLayout = false
    cellSize = CGSize(width: 100.0, height: 100.0)
    layoutAttributesCache = [UICollectionViewLayoutAttributes]()
    layoutRectCache = CGRectZero
    indexPathCache = NSIndexPath(forRow: 0, inSection: 0)
    firstOpenSpace = CGPointZero
    furthestCellPosition = CGPointZero
    indexPathByPosition = [Int: [Int: NSIndexPath]]()
    positionByIndexPath = [UInt: [UInt: NSValue]]()

    super.init(coder: aDecoder)
  }
}

// MARK:- UICollectionView Overrides
extension MosaicLayout {
  override func collectionViewContentSize() -> CGSize {
    guard let cv = collectionView else {
      return CGSizeZero
    }

    let contentRect = UIEdgeInsetsInsetRect(cv.frame, cv.contentInset)
    let size: CGSize

    switch scrollDirection {
    case .Vertical:
      size = CGSize(
        width: CGRectGetWidth(contentRect), height: (furthestCellPosition.y + 1) * cellSize.height
      )
    case .Horizontal:
      size = CGSize(
        width:(furthestCellPosition.x + 1) * cellSize.width, height: CGRectGetHeight(contentRect)
      )
    }

    return size
  }

  override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    if CGRectEqualToRect(rect, layoutRectCache) {
      return layoutAttributesCache
    }

    layoutRectCache = rect

    // the index may be negative!
    let unboundIndexStart: Int
    let length: UInt

    switch scrollDirection {
    case .Vertical:
      unboundIndexStart = Int(rect.origin.y / cellSize.height)
      length = UInt(rect.size.height / cellSize.height)
    case .Horizontal:
      unboundIndexStart = Int(rect.origin.x / cellSize.width)
      length = UInt(rect.size.width / cellSize.width) + 1
    }

    let unboundIndexEnd: Int = unboundIndexStart + Int(length)

    if preemptivelyRenderLayout {
      insertCellsToUnboundIndex(Int.max)
    }

    else {
      insertCellsToUnboundIndex(unboundIndexEnd)
    }

    var attributes = Set<UICollectionViewLayoutAttributes>()

    // O(n^2)
    for var unboundIndex = unboundIndexStart; unboundIndex < unboundIndexEnd; unboundIndex++ {
      for var boundIndex = 0; boundIndex < Int(maximumNumberOfCellsInBounds); boundIndex++ {
        var position: CGPoint

        switch scrollDirection {
        case .Vertical:
          position = CGPoint(x: CGFloat(boundIndex), y: CGFloat(unboundIndex))
        case .Horizontal:
          position = CGPoint(x: CGFloat(unboundIndex), y: CGFloat(boundIndex))
        }

        if let indexPath = self.indexPathForPosition(position),
          let attribute = self.layoutAttributesForItemAtIndexPath(indexPath) {
            attributes.insert(attribute)
        }
      }
    }

    // Cache the attributes
    layoutAttributesCache = Array(attributes)

    return layoutAttributesCache
  }

  override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {

    guard let cv = collectionView, let d = delegate else {
      return nil
    }

    let frame: CGRect
    let attributes: UICollectionViewLayoutAttributes
    var insets = UIEdgeInsetsZero

    if d.respondsToSelector("collectionView:layout:insetsForItemAtIndexPath:") {
      insets = d.collectionView(cv, layout: self, insetsForItemAtIndexPath: indexPath)
    }

    frame = rectForIndexPath(indexPath)
    attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
    attributes.frame = UIEdgeInsetsInsetRect(frame, insets)

    return attributes
  }

  override func prepareLayout() {
    super.prepareLayout()

    guard delegate != nil, let cv = collectionView else {
      return
    }

    let scrollFrame = CGRect(
      x: cv.contentOffset.x,
      y: cv.contentOffset.y,
      width: cv.frame.size.width,
      height: cv.frame.size.height
    )

    let unboundIndex: Int
    switch scrollDirection {
    case .Vertical:
      unboundIndex = Int((CGRectGetMaxY(scrollFrame) / cellSize.height) + 1)

    case .Horizontal:
      unboundIndex = Int((CGRectGetMaxX(scrollFrame) / cellSize.width) + 1)
    }

    if (preemptivelyRenderLayout) {
      insertCellsToUnboundIndex(Int.max)
    }

    else {
      insertCellsToUnboundIndex(unboundIndex)
    }
  }

  override func prepareForCollectionViewUpdates(updateItems: [UICollectionViewUpdateItem]) {
    super.prepareForCollectionViewUpdates(updateItems)

    for item in updateItems {
      switch item.updateAction {
      case .Insert, .Move:
        if let indexPath = item.indexPathAfterUpdate {
          insertCellsToIndexPath(indexPath)
        }

      default:
        break
      }
    }
  }

  override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
    return !(CGSizeEqualToSize(newBounds.size, collectionView?.frame.size ?? CGSizeZero))
  }

  override func invalidateLayout() {
    super.invalidateLayout()

    indexPathCache = NSIndexPath(forRow: 0, inSection: 0)
    layoutAttributesCache = [UICollectionViewLayoutAttributes]()
    furthestCellPosition = CGPointZero
    layoutRectCache = CGRectZero
    firstOpenSpace = CGPointZero
    indexPathByPosition = [Int: [Int: NSIndexPath]]()
    positionByIndexPath = [UInt: [UInt: NSValue]]()

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
    let padding: CGFloat
    let contentRect = UIEdgeInsetsInsetRect(cv.frame, cv.contentInset)
    let result: CGRect

    switch scrollDirection {
    case .Vertical:
      let width = CGRectGetWidth(contentRect)
      padding = (width - CGFloat(maximumNumberOfCellsInBounds) * cellSize.width) / 2
      result = CGRect(
        x: position.x * cellSize.width + padding,
        y: position.y * cellSize.height,
        width: aCellSize.width * cellSize.width,
        height: aCellSize.height * cellSize.height
      )

    case .Horizontal:
      let height = CGRectGetHeight(contentRect)
      padding = (height - CGFloat(maximumNumberOfCellsInBounds) * cellSize.height) / 2
      result = CGRect(
        x: position.x * cellSize.width,
        y: position.y * cellSize.height + padding,
        width: aCellSize.width * cellSize.width,
        height: aCellSize.height * cellSize.height
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

    return CGSize(width: 1.0, height: 1.0)
  }

  private func positionForIndexPath(indexPath: NSIndexPath) -> CGPoint {
    let position: CGPoint
    // Check if the cell has a position
    if let p = positionByIndexPath[UInt(indexPath.section)]?[UInt(indexPath.row)] {
      position = p.CGPointValue()

    }

    else {
      // Make a new position if the position did not exist.
      insertCellsToIndexPath(indexPath)

      position = positionByIndexPath[UInt(indexPath.section)]?[UInt(indexPath.row)]?.CGPointValue()
        ?? CGPointZero
    }


    return position
  }

  private func indexPathForPosition(position: CGPoint) -> NSIndexPath? {
    let unboundIndex, boundIndex: Int

    switch scrollDirection {
    case .Vertical:
      unboundIndex = Int(position.y)
      boundIndex = Int(position.x)

    case .Horizontal:
      unboundIndex = Int(position.x)
      boundIndex = Int(position.y)
    }

    return indexPathByPosition[boundIndex]?[unboundIndex]
  }
}

// MARK:- Setters
extension MosaicLayout {
  private func setPosition(position: CGPoint, forIndexPath indexPath: NSIndexPath) {
    let unboundIndex, boundIndex: Int

    switch scrollDirection {
    case .Vertical:
      unboundIndex = Int(position.y)
      boundIndex = Int(position.x)

    case .Horizontal:
      unboundIndex = Int(position.x)
      boundIndex = Int(position.y)
    }

    if indexPathByPosition[boundIndex] == nil {
      indexPathByPosition[boundIndex] = [Int: NSIndexPath]()
    }

    indexPathByPosition[boundIndex]![unboundIndex] = indexPath
  }

  private func setIndexPath(indexPath: NSIndexPath, forPosition position: CGPoint) {
    if positionByIndexPath[UInt(indexPath.section)] == nil {
      positionByIndexPath[UInt(indexPath.section)] = [UInt: NSValue]()
    }

    positionByIndexPath[UInt(indexPath.section)]?[UInt(indexPath.row)] = NSValue(CGPoint: position)
  }
}

// MARK:- Cell insertion
extension MosaicLayout {

  private func insertCellAtIndexPath(indexPath: NSIndexPath) -> Bool {
    let aCellSize = sizeForCellAtIndexPath(indexPath)

    return !traverseOpenCells({[unowned self] (let cellOrigin: CGPoint) in

      let didTraverseAllCells = self.traverseCellsForPosition(
        cellOrigin,
        withSize: aCellSize,
        closure: {[unowned self] (let position: CGPoint) in
          let hasSpaceAvailable: Bool = Bool(self.indexPathForPosition(position) == nil)
          var isInBounds: Bool = false
          var hasMaximumBoundSize: Bool = false

          switch self.scrollDirection {
          case .Vertical:
            isInBounds = (UInt(position.x) < self.maximumNumberOfCellsInBounds);
            hasMaximumBoundSize = (cellOrigin.x == 0);
          case .Horizontal:
            isInBounds = (UInt(position.y) < self.maximumNumberOfCellsInBounds);
            hasMaximumBoundSize = (cellOrigin.y == 0);
          }

          if hasSpaceAvailable && hasMaximumBoundSize && !isInBounds {
            print("View is not large enough to hold cell... inserting anyway.")
            return true
          }

          return (hasSpaceAvailable && isInBounds)
        }
      )

      if !didTraverseAllCells {
        return true
      }

      self.setIndexPath(indexPath, forPosition: cellOrigin)

      self.traverseCellsForPosition(
        cellOrigin,
        withSize: aCellSize,
        closure: {[unowned self] (let aPosition: CGPoint) in
          self.setPosition(aPosition, forIndexPath: indexPath)
          self.furthestCellPosition = aPosition

          return true
        }
      )

      return false
      }
    )
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

  private func insertCellsToUnboundIndex(unboundIndex: Int) {
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
          if Int(firstOpenSpace.y) >= unboundIndex {
            return
          }

          break

        case .Horizontal:
          if Int(firstOpenSpace.x) >= unboundIndex {
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
  private func traverseOpenCells(closure: (position: CGPoint) -> Bool) -> Bool {
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
        var position: CGPoint

        switch scrollDirection {
        case .Vertical:
          position = CGPoint(x: CGFloat(boundIndex), y: CGFloat(unboundIndex))

        case .Horizontal:
          position = CGPoint(x: CGFloat(unboundIndex), y: CGFloat(boundIndex))
        }


        if indexPathForPosition(position) != nil {
          continue
        }

        if allTakenBefore {
          firstOpenSpace = position
          allTakenBefore = false
        }

        if !closure(position: position) {
          // break
          return false
        }
      }

      unboundIndex++
      
    } while(true)
  }
  
  private func traverseCellsForPosition(position: CGPoint, withSize size: CGSize, closure: (point: CGPoint) -> Bool) -> Bool {
    var column: UInt
    var row: UInt
    
    // O(n^2)
    for column = UInt(position.x); column < UInt(position.x + size.width); column++ {
      for row = UInt(position.y); row < UInt(position.y + size.height); row++ {
        if !closure(point: CGPoint(x: CGFloat(column), y: CGFloat(row))) {
          return false
        }
      }
    }
    
    return true
  }
}
