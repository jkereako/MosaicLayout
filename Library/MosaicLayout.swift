//
//  MosaicLayout.swift
//  MosaicLayout
//
//  Created by Jeffrey Kereakoglow on 12/10/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

public class MosaicLayout: UICollectionViewLayout {
    //-- Interface
    public weak var delegate: MosaicLayoutDelegate?

    public var preemptivelyRenderLayout = false
    public var scrollDirection = UICollectionViewScrollDirection.vertical {
        didSet {
            invalidateLayout()
        }
    }

    public var cellSize = CGSize(width: 100.0, height: 100.0) {
        didSet {
            invalidateLayout()
        }
    }

    //-- things
    public var firstOpenSpace = CGPoint.zero

    public var furthestCellPosition = CGPoint.zero {
        didSet {
            // Allow the property to be reset to zero
            if (furthestCellPosition != CGPoint.zero) {
                furthestCellPosition = CGPoint(x: max(furthestCellPosition.x, oldValue.x),
                                               y: max(furthestCellPosition.y, oldValue.y))
            }
        }
    }

    // This is a map of integers to dictionaries of integers mapped to index paths
    public var indexPathByPosition = [Int: [Int: IndexPath]]()
    public var positionByIndexPath = [UInt: [UInt: CGPoint]]()

    //-- Caching
    // The variables below are used for caching to prevent too much work.
    public var layoutAttributesCache = [UICollectionViewLayoutAttributes]()
    public var layoutRectCache = CGRect.zero
    public var indexPathCache = IndexPath()

    public var maximumNumberOfCellsInBounds: UInt {
        var size: UInt = 0;
        let contentRect = UIEdgeInsetsInsetRect(collectionView!.frame, collectionView!.contentInset)

        switch (scrollDirection) {
        case .vertical:
            size = UInt(contentRect.width / cellSize.width)

        case .horizontal:
            size = UInt(contentRect.height / cellSize.height)
        }

        if (size == 0) {
            print("Cannot fit cell in contect rect. Defaulting to 1")
            return 1
        }

        return size
    }
}

// MARK:- UICollectionView Overrides
public extension MosaicLayout {
    override public var collectionViewContentSize: CGSize {
        let contentRect = UIEdgeInsetsInsetRect(collectionView!.frame, collectionView!.contentInset)
        let size: CGSize

        switch scrollDirection {
        case .vertical:
            size = CGSize(width: contentRect.width, height: (furthestCellPosition.y + 1) * cellSize.height)

        case .horizontal:
            size = CGSize(width:(furthestCellPosition.x + 1) * cellSize.width, height: contentRect.height)
        }

        return size
    }

    override public func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        if rect.equalTo(layoutRectCache) {
            return layoutAttributesCache
        }

        layoutRectCache = rect

        // the index may be negative!
        let unboundIndexStart: Int
        let length: UInt

        switch scrollDirection {
        case .vertical:
            unboundIndexStart = Int(rect.origin.y / cellSize.height)
            length = UInt(rect.size.height / cellSize.height)

        case .horizontal:
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
                var position = CGPoint.zero

                switch scrollDirection {
                case .vertical:
                    position = CGPoint(x: CGFloat(boundIndex), y: CGFloat(unboundIndex))

                case .horizontal:
                    position = CGPoint(x: CGFloat(unboundIndex), y: CGFloat(boundIndex))
                }

                if let indexPath = self.indexPathForPosition(position), let attribute = self.layoutAttributesForItem(at: indexPath) {
                    attributes.insert(attribute)
                }
            }
        }

        // Cache the attributes
        layoutAttributesCache = Array(attributes)

        return layoutAttributesCache
    }

    override public func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let frame: CGRect
        let attributes: UICollectionViewLayoutAttributes
        var insets = UIEdgeInsets.zero

        if let d = delegate {
            insets = d.collectionView(collectionView!, layout: self, insetsForItemAtIndexPath: indexPath)
        }

        frame = rectForIndexPath(indexPath)
        attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = UIEdgeInsetsInsetRect(frame, insets)

        return attributes
    }

    override public func prepare() {
        super.prepare()

        let scrollFrame = CGRect(
            x: collectionView!.contentOffset.x,
            y: collectionView!.contentOffset.y,
            width: collectionView!.frame.size.width,
            height: collectionView!.frame.size.height
        )

        let unboundIndex: Int
        switch scrollDirection {
        case .vertical:
            unboundIndex = Int((scrollFrame.maxY / cellSize.height) + 1)

        case .horizontal:
            unboundIndex = Int((scrollFrame.maxX / cellSize.width) + 1)
        }

        if preemptivelyRenderLayout {
            insertCellsToUnboundIndex(Int.max)
        }
        else {
            insertCellsToUnboundIndex(unboundIndex)
        }
    }

    override public func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)

        for item in updateItems {
            switch item.updateAction {
            case .insert, .move:
                if let indexPath = item.indexPathAfterUpdate {
                    insertCellsToIndexPath(indexPath)
                }

            default:
                break
            }
        }
    }

    override public func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return !(newBounds.size.equalTo(collectionView?.frame.size ?? CGSize.zero))
    }

    override public func invalidateLayout() {
        super.invalidateLayout()

        indexPathCache = IndexPath(row: 0, section: 0)
        layoutAttributesCache = [UICollectionViewLayoutAttributes]()
        furthestCellPosition = CGPoint.zero
        layoutRectCache = CGRect.zero
        firstOpenSpace = CGPoint.zero
        indexPathByPosition = [Int: [Int: IndexPath]]()
        positionByIndexPath = [UInt: [UInt: CGPoint]]()
    }
}

// MARK:- Getters
private extension MosaicLayout {
    func rectForIndexPath(_ indexPath: IndexPath) -> CGRect {
        let position = positionForIndexPath(indexPath)
        let aCellSize = sizeForCellAtIndexPath(indexPath)
        let padding: CGFloat
        let contentRect = UIEdgeInsetsInsetRect(collectionView!.frame, collectionView!.contentInset)
        let result: CGRect

        switch scrollDirection {
        case .vertical:
            let width = contentRect.width
            padding = (width - CGFloat(maximumNumberOfCellsInBounds) * cellSize.width) / 2
            result = CGRect(
                x: position.x * cellSize.width + padding,
                y: position.y * cellSize.height,
                width: aCellSize.width * cellSize.width,
                height: aCellSize.height * cellSize.height
            )

        case .horizontal:
            let height = contentRect.height
            padding = (height - CGFloat(maximumNumberOfCellsInBounds) * cellSize.height) / 2
            result = CGRect(
                x: position.x * cellSize.width,
                y: position.y * cellSize.height + padding,
                width: aCellSize.width * cellSize.width,
                height: aCellSize.height * cellSize.height
            )
        }

        return result.integral
    }

    func sizeForCellAtIndexPath(_ indexPath: IndexPath) -> CGSize {
        if let d = delegate {
            return d.collectionView(collectionView!, layout: self, sizeForItemAtIndexPath: indexPath)
        }

        return CGSize(width: 1.0, height: 1.0)
    }

    func positionForIndexPath(_ indexPath: IndexPath) -> CGPoint {
        // Check if the cell has a position
        if let position = positionByIndexPath[UInt(indexPath.section)]?[UInt(indexPath.row)] {
            return position
        }

        // Make a new position if the position did not exist.
        insertCellsToIndexPath(indexPath)

        return positionByIndexPath[UInt(indexPath.section)]?[UInt(indexPath.row)] ?? CGPoint.zero
    }

    func indexPathForPosition(_ position: CGPoint) -> IndexPath? {
        let unboundIndex, boundIndex: Int

        switch scrollDirection {
        case .vertical:
            unboundIndex = Int(position.y)
            boundIndex = Int(position.x)

        case .horizontal:
            unboundIndex = Int(position.x)
            boundIndex = Int(position.y)
        }

        return indexPathByPosition[boundIndex]?[unboundIndex]
    }
}

// MARK:- Setters
private extension MosaicLayout {
    func setPosition(_ position: CGPoint, forIndexPath indexPath: IndexPath) {
        let unboundIndex, boundIndex: Int

        switch scrollDirection {
        case .vertical:
            unboundIndex = Int(position.y)
            boundIndex = Int(position.x)

        case .horizontal:
            unboundIndex = Int(position.x)
            boundIndex = Int(position.y)
        }

        if indexPathByPosition[boundIndex] == nil {
            indexPathByPosition[boundIndex] = [Int: IndexPath]()
        }

        indexPathByPosition[boundIndex]![unboundIndex] = indexPath
    }

    func setIndexPath(_ indexPath: IndexPath, forPosition position: CGPoint) {
        if positionByIndexPath[UInt(indexPath.section)] == nil {
            positionByIndexPath[UInt(indexPath.section)] = [UInt: CGPoint]()
        }

        positionByIndexPath[UInt(indexPath.section)]?[UInt(indexPath.row)] = position
    }
}

// MARK:- Cell insertion
private extension MosaicLayout {
    func insertCellAtIndexPath(_ indexPath: IndexPath) -> Bool {
        let aCellSize = sizeForCellAtIndexPath(indexPath)

        return !traverseOpenCells({
            [unowned self] (cellOrigin: CGPoint) in

            let didTraverseAllCells = self.traverseCellsForPosition(
                cellOrigin,
                withSize: aCellSize,
                closure: {
                    [unowned self] (position: CGPoint) in
                    let hasSpaceAvailable: Bool = Bool(self.indexPathForPosition(position) == nil)
                    var isInBounds: Bool = false
                    var hasMaximumBoundSize: Bool = false

                    switch self.scrollDirection {
                    case .vertical:
                        isInBounds = (UInt(position.x) < self.maximumNumberOfCellsInBounds);
                        hasMaximumBoundSize = (cellOrigin.x == 0);
                    case .horizontal:
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

            let _ = self.traverseCellsForPosition(
                cellOrigin,
                withSize: aCellSize,
                closure: {
                    [unowned self] (aPosition: CGPoint) in
                    self.setPosition(aPosition, forIndexPath: indexPath)
                    self.furthestCellPosition = aPosition

                    return true
                }
            )

            return false
        })
    }

    func insertCellsToIndexPath(_ indexPath: IndexPath) {
        for section in indexPathCache.section..<collectionView!.numberOfSections {
            for row in indexPathCache.row + 1..<collectionView!.numberOfItems(inSection: section) {
                // Return if we are past the desired row
                if section >= indexPath.section && row > indexPath.row {
                    return
                }

                let newIndexPath = IndexPath(item: row, section: section)

                if insertCellAtIndexPath(indexPath) {
                    indexPathCache = newIndexPath
                }
            }
        }
    }

    func insertCellsToUnboundIndex(_ unboundIndex: Int) {
        let sectionCount = collectionView?.numberOfSections ?? 0

        //for var aRow = row + 1; row < rows; ++aRow
        for section in indexPathCache.section..<sectionCount {
            let rowCount = collectionView?.numberOfItems(inSection: section) ?? 0

            for row in indexPathCache.row + 1..<rowCount {
                let indexPath = IndexPath(row: row, section: section)

                if insertCellAtIndexPath(indexPath) {
                    indexPathCache = indexPath
                }

                // Test whether we are beyond the unbound index.
                switch scrollDirection {
                case .vertical:
                    guard Int(firstOpenSpace.y) < unboundIndex else {
                        return
                    }

                    break

                case .horizontal:
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
private extension MosaicLayout {
    func traverseOpenCells(_ closure: (_ position: CGPoint) -> Bool) -> Bool {
        var allTakenBefore = true
        var unboundIndex: UInt

        switch scrollDirection {
        case .vertical:
            unboundIndex = UInt(firstOpenSpace.y)

        case .horizontal:
            unboundIndex = UInt(firstOpenSpace.x)
        }

        repeat {
            for boundIndex in 0..<maximumNumberOfCellsInBounds {
                var position = CGPoint.zero

                switch scrollDirection {
                case .vertical:
                    position = CGPoint(x: CGFloat(boundIndex), y: CGFloat(unboundIndex))

                case .horizontal:
                    position = CGPoint(x: CGFloat(unboundIndex), y: CGFloat(boundIndex))
                }


                if indexPathForPosition(position) != nil {
                    continue
                }

                if allTakenBefore {
                    firstOpenSpace = position
                    allTakenBefore = false
                }

                if !closure(position) {
                    // break
                    return false
                }
            }

            unboundIndex += 1
        } while(true)
    }

    func traverseCellsForPosition(_ position: CGPoint, withSize size: CGSize, closure: (_ point: CGPoint) -> Bool) -> Bool {
        // O(n^2)
        for column in UInt(position.x)..<UInt(position.x + size.width) {
            for row in UInt(position.y)..<UInt(position.y + size.height) {
                if !closure(CGPoint(x: CGFloat(column), y: CGFloat(row))) {
                    return false
                }
            }
        }

        return true
    }
}
