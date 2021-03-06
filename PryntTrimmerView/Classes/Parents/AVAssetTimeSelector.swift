//
//  AVAssetTimeSelector.swift
//  Pods
//
//  Created by Henry on 06/04/2017.
//
//

import UIKit
import AVFoundation

public protocol AVAssetTimeSelectorDelegate: class {
    func thumbnailFor(_ imageTime: CMTime, completion: @escaping (UIImage?)->Void)
}

/// A generic class to display an asset into a scroll view with thumbnail images, and make the equivalence between a time in
// the asset and a position in the scroll view
public class AVAssetTimeSelector: UIView {

    public weak var delegate: AVAssetTimeSelectorDelegate?

    let assetPreview = AssetVideoScrollView()

    public var rideDuration: Double? {
        didSet {
            propertiesDidChange()
        }
    }

    public var thumbnailFrameAspectRatio: CGFloat? {
        didSet {
            propertiesDidChange()
        }
    }

    public var minWidth: CGFloat? {
        didSet {
            assetPreview.minWidth = minWidth
        }
    }
    
    public var maxWidth: CGFloat? {
        didSet {
            assetPreview.maxWidth = maxWidth
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupSubviews()
    }

    func setupSubviews() {
        setupAssetPreview()
        constrainAssetPreview()
    }

    // MARK: - Asset Preview

    func setupAssetPreview() {
        assetPreview.translatesAutoresizingMaskIntoConstraints = false
        assetPreview.delegate = self
        addSubview(assetPreview)
    }

    func constrainAssetPreview() {
        assetPreview.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        assetPreview.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        assetPreview.topAnchor.constraint(equalTo: topAnchor).isActive = true
        assetPreview.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }

    func propertiesDidChange(widthIncrement: CGFloat = 0) {
        guard let rideDuration = rideDuration,
              let thumbnailFrameAspectRatio = thumbnailFrameAspectRatio else {
            return
        }

        assetPreview.recalculateThumbnailTimes(for: rideDuration, thumbnailFrameAspectRatio: thumbnailFrameAspectRatio, widthIncrement: widthIncrement)
    }

    // MARK: - Time & Position Equivalence

    func time(from position: CGFloat) -> CMTime? {
        return assetPreview.time(from: position)
    }

    func position(from time: CMTime) -> CGFloat? {
        guard let duration = rideDuration else {
            return nil
        }
        let timeRatio = CGFloat(time.value) / CGFloat(duration)
        return timeRatio * assetPreview.realContentSize.width
    }
}

extension AVAssetTimeSelector: AssetVideoScrollViewDelegate {

    func thumbnailFor(_ imageTime: CMTime, completion: @escaping (UIImage?)->Void) {
        delegate?.thumbnailFor(imageTime, completion: completion)
    }

    @objc func didUpdateDimensions() {
    }

    @objc func contentOffsetDidChange() {
    }
}
