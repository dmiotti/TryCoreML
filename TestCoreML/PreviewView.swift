//
//  PreviewView.swift
//  TestCoreML
//
//  Created by David Miotti on 06/06/2017.
//  Copyright © 2017 Wopata. All rights reserved.
//

import UIKit
import AVFoundation

final class PreviewView: UIView {

    override class var layerClass: AnyClass {
        get {
            return AVCaptureVideoPreviewLayer.self
        }
    }

    private var squareHUD = UIView()
    private var widthHUDLayoutConstraints: NSLayoutConstraint!
    private var heightHUDLayoutConstraints: NSLayoutConstraint!

    var modelType: AppMLModel.ModelType? {
        didSet {
            applySizeBasedOnModelType()
        }
    }

    private func applySizeBasedOnModelType() {
        guard let modelType = modelType else { return }
        let ratio = 1.0 / UIScreen.main.scale
        let size = modelType.imageSize.applying(CGAffineTransform(scaleX: ratio, y: ratio))
        widthHUDLayoutConstraints.constant = size.width
        heightHUDLayoutConstraints.constant = size.height
        UIView.animate(withDuration: 0.35, animations: layoutIfNeeded)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        addSubview(squareHUD)
        squareHUD.layer.borderColor = UIColor.yellow.withAlphaComponent(0.5).cgColor
        squareHUD.layer.borderWidth = 1
        squareHUD.backgroundColor = .clear
        squareHUD.translatesAutoresizingMaskIntoConstraints = false
        configureLayoutConstraints()
    }

    var session: AVCaptureSession? {
        get {
            if let previewLayer = layer as? AVCaptureVideoPreviewLayer {
                return previewLayer.session
            }
            return nil
        }
        set {
            if let previewLayer = layer as? AVCaptureVideoPreviewLayer {
                previewLayer.session = newValue
            }
        }
    }

    private func configureLayoutConstraints() {
        let centerYContraint = NSLayoutConstraint(item: squareHUD, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0.0)
        let centerXConstraint = NSLayoutConstraint(item: squareHUD, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0.0)
        widthHUDLayoutConstraints = NSLayoutConstraint(item: squareHUD, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0)
        heightHUDLayoutConstraints = NSLayoutConstraint(item: squareHUD, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0)
        addConstraints([centerYContraint, centerXConstraint, widthHUDLayoutConstraints, heightHUDLayoutConstraints])
    }
}
