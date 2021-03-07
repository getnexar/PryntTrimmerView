//
//  PryntTrimmerView.swift
//  PryntTrimmerView
//
//  Created by HHK on 27/03/2017.
//  Copyright © 2017 Prynt. All rights reserved.
//

import AVFoundation
import UIKit

public class TimeLabelView: UIView {
    
    private var label: UILabel = {
        var label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
   private var view: UIView = {
        var view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
   }()
    
    private var stackView: UIStackView = {
        var stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        return stackView
    }()
    
    public var font: UIFont? {
        didSet {
            label.font = font
        }
    }
    
    public var color: UIColor? {
        didSet {
            label.textColor = color
            view.backgroundColor = color
        }
    }
    
    public var text: String? {
        didSet {
            label.text = text
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
        makeConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
        addSubviews()
        makeConstraints()
    }
    
    private func addSubviews() {
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(view)
        addSubview(stackView)
    }
    
    private func makeConstraints() {
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
    }
}

/// A delegate to be notified of when the thumb position has changed. Useful to link an instance of the ThumbSelectorView to a
/// video preview like an `AVPlayer`.
public protocol TrimmerViewDelegate: AVAssetTimeSelectorDelegate {
    func didChangePositionBar(_ playerTime: CMTime)
    func positionBarStoppedMoving(_ playerTime: CMTime)
    func trimmerHandleDidMove(triggerHandle: TrimmerView.TriggeredHandle)
}

/// A view to select a specific time range of a video. It consists of an asset preview with thumbnails inside a scroll view, two
/// handles on the side to select the beginning and the end of the range, and a position bar to synchronize the control with a
/// video preview, typically with an `AVPlayer`.
/// Load the video by setting the `asset` property. Access the `startTime` and `endTime` of the view to get the selected time
// range
@IBDesignable public class TrimmerView: AVAssetTimeSelector {

    public enum TriggeredHandle {
        case left
        case right
        case unknown
    }

    // MARK: - Properties

    private var trimmerDelegate: TrimmerViewDelegate? {
        return delegate as? TrimmerViewDelegate
    }

    // MARK: Color Customization

    /// The color of the main border of the view
    @IBInspectable public var mainColor: UIColor = UIColor.orange {
        didSet {
            updateMainColor()
        }
    }
    
    @IBInspectable private var pressedMainColor: UIColor = UIColor.orange

    /// The color of the handles on the side of the view
    @IBInspectable public var handleColor: UIColor = UIColor.gray {
        didSet {
           updateHandleColor()
        }
    }

    // labels for the handlers
    public var rightHandleLabel = TimeLabelView()
    public var leftHandleLabel  = TimeLabelView()

    // MARK: Subviews

    private let trimView = UIView()
    private let topBorder = UIView()
    private let bottomBorder = UIView()
    private let leftHandleView = HandlerView()
    private let rightHandleView = HandlerView()
    private let leftHandleKnob = UIImageView()
    private let rightHandleKnob = UIImageView()
    private let leftMaskView = UIView()
    private let rightMaskView = UIView()
    private let positionBar = UIView()
    
    // MARK: Constraints
    
    private var currentLeftHandleConstraint: CGFloat = 0
    private var currentRightHandleConstraint: CGFloat = 0
    private var leftHandleConstraint: NSLayoutConstraint?
    private var rightHandleConstraint: NSLayoutConstraint?
    private var positionConstraint: NSLayoutConstraint?
    private var leftMaskConstraint: NSLayoutConstraint?
    private var rightMaskConstraint: NSLayoutConstraint?

    private let handleWidth: CGFloat = 20
    
    /// The maximum duration allowed for the trimming. Change it before setting the asset, as the asset preview
    public var maxDuration: Double = 15

    /// The minimum duration allowed for the trimming. The handles won't pan further if the minimum duration is attained.
    public var minDuration: Double = 3

    public var maxOnscreenDuration: Double = 1800 {
        didSet {
            assetPreview.maxOnscreenDuration = maxOnscreenDuration
        }
    }
    
    public var fullWidth: CGFloat { assetPreview.contentWidth + 2 * handleWidth }
    
    public override var minWidth: CGFloat? {
        didSet {
            assetPreview.minWidth = minWidth
        }
    }
    
    public override var maxWidth: CGFloat? {
        didSet {
            assetPreview.maxWidth = maxWidth
        }
    }

    // MARK: - View & constraints configurations

    override func didUpdateDimensions() {
        initializeHandleTimes()
        refreshHandles()
    }

    override func contentOffsetDidChange() {
        refreshMaskViews()
        refreshHandles()
    }

    override func setupSubviews() {
        super.setupSubviews()
        backgroundColor = UIColor.clear
        layer.zPosition = 1
        setupHandleView()
        setupTrimmerView()
        setupMaskView()
        setUpPositionBar()
        setupGestures()
        updateMainColor()
        updateHandleColor()
    }
    
    public func initializeHandleTimes() {
        guard
            let leftHandleConstraint = leftHandleConstraint,
            let rightHandleConstraint = rightHandleConstraint,
            leftHandleConstraint.constant == 0,
            rightHandleConstraint.constant == 0,
            let rideDuration = rideDuration else {
            return
        }
        startTime = CMTimeMake(value: 0, timescale: 1)
        endTime = CMTime(value: Int64(rideDuration), timescale: 1)
        positionTime = startTime
        layoutSubviews()
    }
    
    public func setUpUI(mainColor: UIColor,
                        pressedMainColor: UIColor,
                        maskBackgroundColor: UIColor,
                        maskBorderColor: CGColor,
                        handleColor: UIColor,
                        labelFont: UIFont?,
                        labelColor: UIColor) {
        self.mainColor = mainColor
        self.pressedMainColor = pressedMainColor
        self.handleColor = handleColor
        leftMaskView.backgroundColor = maskBackgroundColor
        leftMaskView.layer.borderColor = maskBorderColor
        rightMaskView.backgroundColor = maskBackgroundColor
        rightMaskView.layer.borderColor = maskBorderColor
        rightHandleLabel.font = labelFont
        rightHandleLabel.color = labelColor
        leftHandleLabel.font = labelFont
        leftHandleLabel.color = labelColor
    }

    private func updateMainColor() {
        changeHandleStateColor(color: mainColor)
    }
    
    private func changeHandleStateColor(color: UIColor) {
        topBorder.backgroundColor = color
        bottomBorder.backgroundColor = color
        leftHandleView.backgroundColor = color
        rightHandleView.backgroundColor = color
    }
    
    private func updateHandleColor() {
        leftHandleKnob.tintColor = handleColor
        leftHandleKnob.backgroundColor = .clear
        rightHandleKnob.tintColor = handleColor
        rightHandleKnob.backgroundColor = .clear
    }
    
    override func constrainAssetPreview() {
        assetPreview.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        assetPreview.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        assetPreview.topAnchor.constraint(equalTo: topAnchor).isActive = true
        assetPreview.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }

    private func setupTrimmerView() {
        assetPreview.layer.cornerRadius = 2.0
        trimView.layer.cornerRadius = 2.0
        trimView.translatesAutoresizingMaskIntoConstraints = false
        trimView.isUserInteractionEnabled = false
        addSubview(trimView)

        trimView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        trimView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        trimView.leftAnchor.constraint(equalTo: leftHandleView.rightAnchor).isActive = true
        trimView.rightAnchor.constraint(equalTo: rightHandleView.leftAnchor).isActive = true
        
        
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBorder)
        topBorder.bringSubviewToFront(self)
        
        topBorder.heightAnchor.constraint(equalToConstant: 4.0).isActive = true
        topBorder.topAnchor.constraint(equalTo: trimView.topAnchor).isActive = true
        topBorder.leadingAnchor.constraint(equalTo: trimView.leadingAnchor).isActive = true
        topBorder.trailingAnchor.constraint(equalTo: trimView.trailingAnchor).isActive = true
        
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomBorder)
        bottomBorder.bringSubviewToFront(self)

        bottomBorder.heightAnchor.constraint(equalToConstant: 4.0).isActive = true
        bottomBorder.bottomAnchor.constraint(equalTo: trimView.bottomAnchor).isActive = true
        bottomBorder.leadingAnchor.constraint(equalTo: trimView.leadingAnchor).isActive = true
        bottomBorder.trailingAnchor.constraint(equalTo: trimView.trailingAnchor).isActive = true
    }

    private func setupHandleView() {
        leftHandleView.isUserInteractionEnabled = true
        leftHandleView.layer.cornerRadius = 8.0
        if #available(iOS 11.0, *) {
            leftHandleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        }
        leftHandleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftHandleView)

        leftHandleView.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        leftHandleView.widthAnchor.constraint(equalToConstant: handleWidth).isActive = true
        leftHandleConstraint = leftHandleView.rightAnchor.constraint(equalTo: assetPreview.collectionView.leftAnchor)
        leftHandleConstraint?.isActive = true
        leftHandleView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        leftHandleKnob.translatesAutoresizingMaskIntoConstraints = false
        leftHandleKnob.image = UIImage(named:"handleLeftArrow")
        leftHandleView.addSubview(leftHandleKnob)

        leftHandleLabel.translatesAutoresizingMaskIntoConstraints = false
        leftHandleView.addSubview(leftHandleLabel)
        leftHandleLabel.bottomAnchor.constraint(equalTo: leftHandleView.topAnchor, constant: -40).isActive = true
        leftHandleLabel.centerXAnchor.constraint(equalTo: leftHandleView.centerXAnchor, constant: -15).isActive = true
        leftHandleLabel.isHidden = true

        leftHandleKnob.heightAnchor.constraint(equalToConstant: 24).isActive = true
        leftHandleKnob.widthAnchor.constraint(equalToConstant: 8).isActive = true
        leftHandleKnob.centerYAnchor.constraint(equalTo: leftHandleView.centerYAnchor).isActive = true
        leftHandleKnob.centerXAnchor.constraint(equalTo: leftHandleView.centerXAnchor).isActive = true

        rightHandleView.isUserInteractionEnabled = true
        rightHandleView.layer.cornerRadius = 8.0
        if #available(iOS 11.0, *) {
            rightHandleView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
        rightHandleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightHandleView)

        rightHandleView.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        rightHandleView.widthAnchor.constraint(equalToConstant: handleWidth).isActive = true
        rightHandleConstraint = rightHandleView.leftAnchor.constraint(equalTo: assetPreview.rightAnchor)
        rightHandleConstraint?.isActive = true
        rightHandleView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        rightHandleKnob.translatesAutoresizingMaskIntoConstraints = false
        rightHandleKnob.image = UIImage(named:"handleRightArrow")
        rightHandleView.addSubview(rightHandleKnob)

        rightHandleLabel.translatesAutoresizingMaskIntoConstraints = false
        rightHandleView.addSubview(rightHandleLabel)
        rightHandleLabel.bottomAnchor.constraint(equalTo: rightHandleView.topAnchor, constant: -40).isActive = true
        rightHandleLabel.centerXAnchor.constraint(equalTo: rightHandleView.centerXAnchor, constant: -24).isActive = true
        rightHandleLabel.isHidden = true

        rightHandleKnob.heightAnchor.constraint(equalToConstant: 24).isActive = true
        rightHandleKnob.widthAnchor.constraint(equalToConstant: 8).isActive = true
        rightHandleKnob.centerYAnchor.constraint(equalTo: rightHandleView.centerYAnchor).isActive = true
        rightHandleKnob.centerXAnchor.constraint(equalTo: rightHandleView.centerXAnchor).isActive = true
    }

    private func setupMaskView() {
        leftMaskView.isUserInteractionEnabled = false
        leftMaskView.translatesAutoresizingMaskIntoConstraints = false
        leftMaskView.layer.cornerRadius = 8.0
        if #available(iOS 11.0, *) {
            leftMaskView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        }
        leftMaskView.layer.borderWidth = 4
        insertSubview(leftMaskView, belowSubview: leftHandleView)

        leftMaskConstraint = leftMaskView.leftAnchor.constraint(equalTo: assetPreview.collectionView.leftAnchor, constant: assetPreview.leftOnScreenInset)
        leftMaskConstraint?.isActive = true
        leftMaskView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        leftMaskView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        leftMaskView.rightAnchor.constraint(equalTo: leftHandleView.centerXAnchor).isActive = true

        rightMaskView.isUserInteractionEnabled = false
        rightMaskView.translatesAutoresizingMaskIntoConstraints = false
        rightMaskView.layer.cornerRadius = 8.0
        if #available(iOS 11.0, *) {
            rightMaskView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
        rightMaskView.layer.borderWidth = 4
        insertSubview(rightMaskView, belowSubview: rightHandleView)

        rightMaskConstraint = rightMaskView.rightAnchor.constraint(equalTo: assetPreview.collectionView.rightAnchor, constant: -assetPreview.rightOnScreenInset)
        rightMaskConstraint?.isActive = true
        rightMaskView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        rightMaskView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        rightMaskView.leftAnchor.constraint(equalTo: rightHandleView.centerXAnchor).isActive = true
    }
    
    private func setUpPositionBar() {
        positionBar.frame = CGRect(x: 0, y: 0, width: 50, height: frame.height)
        positionBar.backgroundColor = .white
        positionBar.center = CGPoint(x: leftHandleView.frame.maxX, y: center.y)
        positionBar.layer.cornerRadius = 6
        positionBar.layer.borderColor = UIColor.gray.cgColor
        positionBar.layer.borderWidth = 1
        positionBar.translatesAutoresizingMaskIntoConstraints = false
        positionBar.isUserInteractionEnabled = true
        addSubview(positionBar)

        positionBar.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        positionBar.widthAnchor.constraint(equalToConstant: 6).isActive = true
        positionBar.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        positionConstraint = positionBar.leftAnchor.constraint(equalTo: leftHandleView.rightAnchor, constant: 0)
        positionConstraint?.isActive = true
    }

    private func setupGestures() {
        let leftPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TrimmerView.handlePanGesture))
        leftHandleView.addGestureRecognizer(leftPanGestureRecognizer)
        let rightPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TrimmerView.handlePanGesture))
        rightHandleView.addGestureRecognizer(rightPanGestureRecognizer)
        
        let positionPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TrimmerView.handlePositionPanGesture))
        positionBar.addGestureRecognizer(positionPanGestureRecognizer)
    }

    // MARK: - Trim Gestures
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let view = gestureRecognizer.view, let superView = gestureRecognizer.view?.superview else { return }
        let triggeredHandle: TriggeredHandle = view == leftHandleView ? .left : view == rightHandleView ? .right : .unknown
        switch gestureRecognizer.state {

        case .began:
            changeHandleStateColor(color: pressedMainColor)
            if view == leftHandleView {
                currentLeftHandleConstraint = leftHandleConstraint!.constant
                leftHandleLabel.isHidden = false
            } else if view == rightHandleView {
                currentRightHandleConstraint = rightHandleConstraint!.constant
                rightHandleLabel.isHidden = false
            } else {
                currentLeftHandleConstraint = leftHandleConstraint!.constant
                currentRightHandleConstraint = rightHandleConstraint!.constant
                
                leftHandleLabel.isHidden = false
                rightHandleLabel.isHidden = false
            }
            positionBar.isHidden = true
        case .changed:
            let translation = gestureRecognizer.translation(in: superView)
            if view == leftHandleView {
                updateLeftConstraint(with: translation)
            } else if view == rightHandleView {
                updateRightConstraint(with: translation)
                
            } else {
                updateLeftConstraint(with: translation)
                updateRightConstraint(with: translation)
            }
            positionTime = startTime
            trimmerDelegate?.trimmerHandleDidMove(triggerHandle:triggeredHandle)
        case .cancelled, .ended, .failed:
            leftHandleLabel.isHidden = true
            rightHandleLabel.isHidden = true
            positionBar.isHidden = false
            changeHandleStateColor(color: mainColor)
            positionTime = startTime
        default: break
        }
    }
    
    @objc func handlePositionPanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let view = gestureRecognizer.view, let superView = gestureRecognizer.view?.superview else { return }
        let triggeredHandle: TriggeredHandle = view == leftHandleView ? .left : view == rightHandleView ? .right : .unknown
        switch gestureRecognizer.state {

        case .began:
//            guard let positionTime = positionTime else { return }
            currentPosition = positionConstraint?.constant ?? 0
        case .changed:
            guard let positionTime = positionTime else { return }
            let translation = gestureRecognizer.translation(in: superView)
            updatePositionConstraint(with: translation, isStopped: false)
            trimmerDelegate?.didChangePositionBar(positionTime)
        case .cancelled, .ended, .failed:
            guard let positionTime = positionTime else { return }
            trimmerDelegate?.positionBarStoppedMoving(positionTime)
        default: break
        }
    }
    
    public func updateWidth(increment: CGFloat) {
        guard !(increment < 0 && assetPreview.contentWidth == minWidth ||
              increment > 0 && assetPreview.contentWidth == maxWidth) else { return }
        propertiesDidChange(widthIncrement: increment)
        refreshHandles()
        layoutSubviews()
    }
    
    private func updateLeftConstraint(with translation: CGPoint) {
        let maxConstraint = max(rightHandleView.frame.origin.x - minimumDistanceBetweenHandle, handleWidth)
        let minConstraint = max(rightHandleView.frame.origin.x - maximumDistanceBetweenHandle, handleWidth)
        var newConstraint = min(max(0, currentLeftHandleConstraint + translation.x), maxConstraint)
        if newConstraint < minConstraint {
            newConstraint = minConstraint
        }
        
        if assetPreview.contentWidth > UIScreen.main.bounds.width && assetPreview.contentOffset.x > 0 {
            var offset: CGFloat = 0
            if newConstraint < 35  {
                offset = -25
            } else if newConstraint > assetPreview.bounds.width - 35 {
                offset = 25
            }
            assetPreview.collectionView.contentOffset.x += offset
            assetPreview.layoutSubviews()
        }
        
        startTime = time(from: assetPreview.contentOffset.x + newConstraint)
        layoutSubviews()

    }

    private func updateRightConstraint(with translation: CGPoint) {
        guard let leftConstraint = leftHandleConstraint else {
            return
        }
        let maxConstraint = min(leftConstraint.constant  + minimumDistanceBetweenHandle - bounds.width, -handleWidth)
        let minConstraint = min(leftConstraint.constant  + maximumDistanceBetweenHandle - bounds.width, -handleWidth)
        var newConstraint = max(min(0, currentRightHandleConstraint + translation.x), maxConstraint)
        if newConstraint > minConstraint {
            newConstraint = minConstraint
        }
        
        if assetPreview.contentWidth > UIScreen.main.bounds.width && assetPreview.collectionView.contentOffset.x < assetPreview.realContentSize.width - assetPreview.bounds.width {
            var offset: CGFloat = 0
            if newConstraint < -assetPreview.bounds.width + 35  {
                offset = -25
            } else if newConstraint > -35  {
                offset = 25
            }
            assetPreview.collectionView.contentOffset.x += offset
            assetPreview.layoutSubviews()
        }

        endTime = time(from: assetPreview.contentOffset.x + assetPreview.bounds.width + newConstraint)

        layoutSubviews()
    }
    
    var currentPosition: CGFloat = 0
    private func updatePositionConstraint(with translation: CGPoint, isStopped: Bool) {
        guard let constant = positionConstraint?.constant,
              let leftHandlePosition = leftHandleConstraint?.constant else { return }
        let newPosition = currentPosition + translation.x
        let maxPosition = rightHandleView.frame.origin.x - leftHandleView.frame.origin.x
        let normalizedPosition = min(max(0, newPosition), maxPosition)
        positionTime = time(from: assetPreview.contentOffset.x + leftHandleView.frame.origin.x + normalizedPosition)
        layoutSubviews()


    }
    
    private func getTime(timeInSeconds: Double) -> String {
        guard timeInSeconds >= 60 else {
           return String(format:"%.0fs", timeInSeconds)
        }
        let seconds = timeInSeconds.truncatingRemainder(dividingBy: 60)
        let minutes = (timeInSeconds / 60)
        return String(format:"%.0fm %.0fs",minutes, seconds)
    }
    
    // MARK: - Time Equivalence

    /// Move the position bar to the given time.
    public func seek(to time: CMTime) {
        if let newPosition = position(from: time) {
            let offsetPosition = newPosition - assetPreview.contentOffset.x - leftHandleView.frame.origin.x
            let maxPosition = rightHandleView.frame.origin.x - (leftHandleView.frame.origin.x + handleWidth)
            let normalizedPosition = min(max(0, offsetPosition), maxPosition)
            positionConstraint?.constant = normalizedPosition
            layoutIfNeeded()
        }
    }

    /// The selected start time for the current asset.
    public var startTime: CMTime? {
        didSet {
            adjustStartHandle()
        }
    }
    
    private func refreshMaskViews() {
        guard let rideDuration = rideDuration,
              let startPosition = position(from: CMTime(seconds: 0, preferredTimescale: 1)),
              let endPosition = position(from: CMTime(seconds: rideDuration, preferredTimescale: 1)) else { return }
        
        leftMaskConstraint?.constant = startPosition - (assetPreview.contentOffset.x - assetPreview.horizontalInset)
        rightMaskConstraint?.constant = endPosition - assetPreview.bounds.width - (assetPreview.contentOffset.x - assetPreview.horizontalInset)
    }
    
    private func refreshHandles() {
        adjustStartHandle()
        adjustEndHandle()
    }
    
    public func adjustStartHandle() {
        guard let startTime = startTime,
              let position = position(from: startTime) else { return }
        leftHandleConstraint?.constant = position - (assetPreview.contentOffset.x - assetPreview.horizontalInset)
        leftHandleLabel.text = getTime(timeInSeconds: CMTimeGetSeconds(startTime))
    }
    
    /// The selected end time for the current asset.
    public var endTime: CMTime? {
        didSet {
            adjustEndHandle()
        }
    }
    
    public func adjustEndHandle() {
        guard let endTime = endTime,
              let position = position(from: endTime) else { return }
        rightHandleConstraint?.constant = position - assetPreview.bounds.width - (assetPreview.contentOffset.x - assetPreview.horizontalInset)
        rightHandleLabel.text = getTime(timeInSeconds: CMTimeGetSeconds(endTime))
    }
    
    public var positionTime: CMTime? {
        didSet {
            guard let positionTime = positionTime else { return }
            seek(to: positionTime)
        }
    }

    public func adjustPositionBar() {
        guard let positionTime = positionTime,
              let position = position(from: positionTime) else { return }
        let offsetPosition = position - assetPreview.contentOffset.x - leftHandleView.frame.origin.x
        let maxPosition = rightHandleView.frame.origin.x - (leftHandleView.frame.origin.x + handleWidth)
        let normalizedPosition = min(max(0, offsetPosition), maxPosition)
        positionConstraint?.constant = normalizedPosition
        layoutIfNeeded()
    }

    private var minimumDistanceBetweenHandle: CGFloat {
        guard let rideDuration = rideDuration else { return 0 }
        return CGFloat(minDuration) * assetPreview.realContentSize.width / CGFloat(rideDuration)
    }

    private var maximumDistanceBetweenHandle: CGFloat {
        guard let rideDuration = rideDuration else { return 0 }
        return CGFloat(maxDuration) * assetPreview.realContentSize.width / CGFloat(rideDuration)
    }
}
