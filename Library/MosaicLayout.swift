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
  
  var preemptivelyRenderLayout = false
  var scrollDirection = UICollectionViewScrollDirection.Vertical{
    didSet {
      invalidateLayout()
    }
  }
  
  var cellSize = CGSize(width: 100.0, height: 100.0) {
    didSet {
      invalidateLayout()
    }
  }
  
  //-- things
  var firstOpenSpace = CGPointZero
  var furthestCellPosition = CGPointZero {
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
  var indexPathByPosition = [Int: [Int: NSIndexPath]]()
  var positionByIndexPath = [UInt: [UInt: CGPoint]]()
  
  //-- Caching
  // The variables below are used for caching to prevent too much work.
  var layoutAttributesCache = [UICollectionViewLayoutAttributes]()
  var layoutRectCache = CGRectZero
  var indexPathCache = NSIndexPath()
  
  var maximumNumberOfCellsInBounds: UInt {
    var size: UInt = 0;
    let contentRect = UIEdgeInsetsInsetRect(collectionView!.frame, collectionView!.contentInset)
    
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
}

// MARK:- UICollectionView Overrides
extension MosaicLayout {
  override func collectionViewContentSize() -> CGSize {
    let contentRect = UIEdgeInsetsInsetRect(collectionView!.frame, collectionView!.contentInset)
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
    for unboundIndex in unboundIndexStart..<unboundIndexEnd {
      for boundIndex in 0..<maximumNumberOfCellsInBounds {
        var position = CGPointZero
        
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
    let frame: CGRect
    let attributes: UICollectionViewLayoutAttributes
    var insets = UIEdgeInsetsZero
    
    if let d = delegate {
      insets = d.collectionView(collectionView!, layout: self, insetsForItemAtIndexPath: indexPath)
    }
    
    frame = rectForIndexPath(indexPath)
    attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
    attributes.frame = UIEdgeInsetsInsetRect(frame, insets)
    
    return attributes
  }
  
  override func prepareLayout() {
    super.prepareLayout()
    
    let scrollFrame = CGRect(
      x: collectionView!.contentOffset.x,
      y: collectionView!.contentOffset.y,
      width: collectionView!.frame.size.width,
      height: collectionView!.frame.size.height
    )
    
    let unboundIndex: Int
    switch scrollDirection {
    case .Vertical:
      unboundIndex = Int((CGRectGetMaxY(scrollFrame) / cellSize.height) + 1)
      
    case .Horizontal:
      unboundIndex = Int((CGRectGetMaxX(scrollFrame) / cellSize.width) + 1)
    }
    
    if preemptivelyRenderLayout {
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
    positionByIndexPath = [UInt: [UInt: CGPoint]]()
    
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
    
    return CGRectIntegral(result)
  }
  
  private func sizeForCellAtIndexPath(indexPath: NSIndexPath) -> CGSize {
    if let d = delegate {
      return d.collectionView(collectionView!, layout: self, sizeForItemAtIndexPath: indexPath)
    }
    
    return CGSize(width: 1.0, height: 1.0)
  }
  
  private func positionForIndexPath(indexPath: NSIndexPath) -> CGPoint {
    let position: CGPoint
    // Check if the cell has a position
    if let p = positionByIndexPath[UInt(indexPath.section)]?[UInt(indexPath.row)] {
      position = p
      
    }
      
    else {
      // Make a new position if the position did not exist.
      insertCellsToIndexPath(indexPath)
      
      position = positionByIndexPath[UInt(indexPath.section)]?[UInt(indexPath.row)] ?? CGPointZero
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
      positionByIndexPath[UInt(indexPath.section)] = [UInt: CGPoint]()
    }
    
    positionByIndexPath[UInt(indexPath.section)]?[UInt(indexPath.row)] = position
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
    for section in indexPathCache.section..<collectionView!.numberOfSections() {
      for row in indexPathCache.row + 1..<collectionView!.numberOfItemsInSection(section) {
        
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
    for section in indexPathCache.section..<sectionCount {
      let rowCount = collectionView?.numberOfItemsInSection(section) ?? 0
      
      for row in indexPathCache.row + 1..<rowCount {
        let indexPath = NSIndexPath(forRow: row, inSection: section)
        
        if insertCellAtIndexPath(indexPath) {
          indexPathCache = indexPath
        }
        
        // Test whether we are beyond the unbound index.
        switch scrollDirection {
        case .Vertical:
          guard Int(firstOpenSpace.y) < unboundIndex else {
            return
          }
          
          break
          
        case .Horizontal:
          guard Int(firstOpenSpace.x) < unboundIndex else {
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
      for boundIndex in 0..<maximumNumberOfCellsInBounds {
        var position = CGPointZero
        
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
      
      unboundIndex += 1
      
    } while(true)
  }
  
  private func traverseCellsForPosition(position: CGPoint, withSize size: CGSize, closure: (point: CGPoint) -> Bool) -> Bool {
    // O(n^2)
    for column in UInt(position.x)..<UInt(position.x + size.width) {
      for row in UInt(position.y)..<UInt(position.y + size.height) {
        if !closure(point: CGPoint(x: CGFloat(column), y: CGFloat(row))) {
          return false
        }
      }
    }
    
    return true
  }
}
