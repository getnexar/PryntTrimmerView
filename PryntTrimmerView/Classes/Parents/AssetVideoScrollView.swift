//
//  AssetVideoScrollView.swift
//  PryntTrimmerView
//
//  Created by HHK on 28/03/2017.
//  Copyright © 2017 Prynt. All rights reserved.
//

import AVFoundation
import UIKit

protocol AssetVideoScrollViewDelegate: class {
    func thumbnailFor(_ imageTime: CMTime, completion: @escaping (UIImage?)->())
    func didUpdateDimensions()
    func contentOffsetDidChange()
}

class AssetVideoScrollView: UIView {

    public weak var delegate: AssetVideoScrollViewDelegate?
    
    let collectionView: UICollectionView
    let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
    var maxOnscreenDuration: Double = 1800
    fileprivate var thumbnailFrameAspectRatio: CGFloat?
    private var duration: TimeInterval?
    fileprivate var thumbnailTimes: [NSValue] = []
    fileprivate var thumbnailSize: CGSize = CGSize.zero
    fileprivate var contentWidth: CGFloat = 0
    fileprivate var lastWidth: CGFloat?
    fileprivate var horizontalInset: CGFloat = 15
    
    var contentSize: CGSize {
        //return CGSize(width: collectionView.contentSize.width - 2 * horizontalInset,
        //             height: collectionView.contentSize.height)
        return collectionView.contentSize
    }
    
    var contentOffset: CGPoint {
        //return CGPoint(x: collectionView.contentOffset.x - horizontalInset,
        //               y: collectionView.contentOffset.y)
        return collectionView.contentOffset
    }
    
    override init(frame: CGRect) {
        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        super.init(coder: aDecoder)
        setupSubviews()
    }
    
    deinit {
        collectionView.removeObserver(self, forKeyPath: "contentOffset")
    }

    private func setupSubviews() {
        backgroundColor = .clear
        clipsToBounds = true

        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.tag = -1
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.bounces = false
        collectionView.delegate = self
        collectionView.dataSource = self
        
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
        
        collectionView.register(ThumbnailCell.self, forCellWithReuseIdentifier: String(describing: ThumbnailCell))
        
        addSubview(collectionView)

        collectionView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        collectionView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        collectionView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        
        collectionView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath, keyPath == "contentOffset" else {
            return
        }
        
        delegate?.contentOffsetDidChange()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        defer {
            self.lastWidth = bounds.width
        }
       
        guard let duration = duration, let thumbnailFrameAspectRatio = thumbnailFrameAspectRatio else {
            return
        }
        
        guard let lastWidth = lastWidth else {
            recalculateThumbnailTimes(for: duration, thumbnailFrameAspectRatio: thumbnailFrameAspectRatio)
            return
        }
        
        guard lastWidth != bounds.width else {
            return
        }
        
        recalculateThumbnailTimes(for: duration, thumbnailFrameAspectRatio: thumbnailFrameAspectRatio)
        recalculateContentOffset(lastWidth)
    }
    
    private func recalculateContentOffset(_ lastWidth: CGFloat) {
        let ratio = bounds.width / lastWidth
        collectionView.contentOffset = CGPoint(x: collectionView.contentOffset.x * ratio,
                                               y: collectionView.contentOffset.y)
    }

    internal func recalculateThumbnailTimes(for duration: TimeInterval, thumbnailFrameAspectRatio: CGFloat) {
        let thumbnailSize = getThumbnailFrameSize(for: thumbnailFrameAspectRatio)
        guard
            thumbnailSize.height.isNormal,
            thumbnailSize.width.isNormal else {
                return
        }
        
        self.thumbnailSize = thumbnailSize
        self.thumbnailFrameAspectRatio = thumbnailFrameAspectRatio
        self.duration = duration
        
        let thumbnailCount =  getThumbnailCount(for: duration)
        thumbnailTimes = getThumbnailTimes(for: duration, numberOfThumbnails: thumbnailCount)
        self.collectionView.reloadData()
        self.collectionView.performBatchUpdates(nil) { _ in
            self.delegate?.didUpdateDimensions()
        }
    }
    
    private func getThumbnailCount(for duration: TimeInterval) -> Int {
        let contentWidthFactor = CGFloat(max(1, duration / maxOnscreenDuration))
        contentWidth = bounds.width * contentWidthFactor
        guard let thumbnailFrameAspectRatio = thumbnailFrameAspectRatio else {
            return 0
        }
        let thumbnailSize = getThumbnailFrameSize(for: thumbnailFrameAspectRatio)
        let thumbnailCount =  thumbnailSize.width > 0 ? Int(ceil(contentWidth / thumbnailSize.width)) : 0
        return thumbnailCount
    }

    private func getThumbnailFrameSize(for aspectRatio: CGFloat) -> CGSize {
        let height = bounds.height
        let width = height * aspectRatio
        return CGSize(width: fabs(width), height: fabs(height))
    }

    private func getThumbnailTimes(for duration: TimeInterval, numberOfThumbnails: Int) -> [NSValue] {
        let timeIncrement = (duration * 1000) / Double(numberOfThumbnails)
        var timesForThumbnails = [NSValue]()
        for index in 0..<numberOfThumbnails {
            let cmTime = CMTime(value: Int64(timeIncrement * Float64(index)), timescale: 1000)
            let nsValue = NSValue(time: cmTime)
            timesForThumbnails.append(nsValue)
        }
        return timesForThumbnails
    }
}

extension AssetVideoScrollView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return thumbnailTimes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: ThumbnailCell), for: indexPath) as? ThumbnailCell else {
            return UICollectionViewCell()
        }
        
        cell.indexPath = indexPath
        
        let time = thumbnailTimes[indexPath.item]
        
        delegate?.thumbnailFor(time.timeValue) { image in
            DispatchQueue.main.async { [weak self, weak cell] () -> Void in
                guard
                    let cell = cell,
                    let cellIndexPath = cell.indexPath,
                    indexPath == cellIndexPath else {
                    return
                }
                
                guard let image = image else {
                    return
                }
                
                cell.imageView.image = image
            }
        }
        
        return cell
    }
}

extension AssetVideoScrollView: UICollectionViewDelegateFlowLayout {
    
    private func isLast(_ indexPath: IndexPath) -> Bool {
        return indexPath.item == thumbnailTimes.count - 1
    }
    
    private func lastCellSize() -> CGSize {
        let height = thumbnailSize.height
        let width = contentWidth - CGFloat(thumbnailTimes.count - 1) * thumbnailSize.width
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let thumbnailFrameAspectRatio = thumbnailFrameAspectRatio else {
            return CGSize.zero
        }
        
        guard !isLast(indexPath) else {
            return lastCellSize()
        }
        
        return thumbnailSize
    }
}

class ThumbnailCell: UICollectionViewCell {
    
    let imageView = UIImageView()
    var indexPath: IndexPath?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonSetup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonSetup()
    }
    
    private func commonSetup() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        imageView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        imageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        imageView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
    }
}
