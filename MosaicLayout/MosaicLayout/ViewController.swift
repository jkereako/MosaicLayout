//
//  ViewController.swift
//  MosaicLayout
//
//  Created by Jeffrey Kereakoglow on 12/10/15.
//  Copyright © 2015 Alexis Digital. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  @IBOutlet weak var viewModel: ViewModel?
  @IBOutlet weak var collectionView: UICollectionView?

  private var animating = false

  override func viewDidLoad() {
    super.viewDidLoad()

    guard let layout = collectionView?.collectionViewLayout as? MosaicLayout,
      let model = viewModel else {
        assertionFailure("The collection view layout is not of type MosaicLayout")
        return
    }

    layout.scrollDirection = .Vertical
    layout.cellSize = CGSizeMake(75.0, 75.0)
    layout.preemptivelyRenderLayout = false
    layout.delegate = model

    model.delegate = self
  }

}

// MARK:- UICollectionViewDelegate
extension ViewController: UICollectionViewDelegate {
  func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {

    guard !animating else {
      return
    }

    animating = true

    viewModel?.collectionView(collectionView,
      removeIndexPath: indexPath,
      completion: {[unowned self] in self.animating = false}
    )
  }
}

extension ViewController: ViewControllerDelegate {
  func configureCell(cell: UICollectionViewCell, withObject object: AnyObject) {
    guard let integer = object as? UInt, let label = cell.viewWithTag(5) as? UILabel else {
      return
    }

    label.text = String(integer)
    cell.backgroundColor = colorForInteger(integer)

  }
}

// MARK:- Actions
extension ViewController {
  @IBAction func addAction(_: UIBarButtonItem) {
    guard let cv = collectionView where !animating else {
      return
    }

    let visibleItems = cv.indexPathsForVisibleItems()

    animating = true

    viewModel?.collectionView(cv,
      addIndexPath: visibleItems.first ?? NSIndexPath(forRow: 0, inSection: 0),
      completion: { [unowned self] in self.animating = false }
    )
  }

  @IBAction func removeAction(_: UIBarButtonItem) {
    guard let cv = collectionView where !animating else {
      return
    }

    let visibleItems = cv.indexPathsForVisibleItems()

    guard visibleItems.count > 0 else {
      return
    }

    let index = Int(arc4random_uniform(UInt32(visibleItems.count)))
    let indexPath = visibleItems[index]

    self.animating = true

    viewModel?.collectionView(cv,
      removeIndexPath: indexPath,
      completion: {[unowned self] in self.animating = false}
    )
  }

  @IBAction func refreshAction(_: UIBarButtonItem) {
    viewModel?.refreshData()
    collectionView?.reloadData()
  }
}

// MARK:- Helpers
extension ViewController {
  private func colorForInteger(integer: UInt) -> UIColor {
    return UIColor(
      hue: CGFloat(((19 * integer) % 255) / 255),
      saturation: 1.0,
      brightness: 1.0,
      alpha: 1.0
    )
  }
}
