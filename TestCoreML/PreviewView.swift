//
//  PreviewView.swift
//  TestCoreML
//
//  Created by David Miotti on 06/06/2017.
//  Copyright © 2017 MuxuMuxu. All rights reserved.
//

import UIKit
import AVFoundation

final class PreviewView: UIView {

    override class var layerClass: AnyClass {
        get {
            return AVCaptureVideoPreviewLayer.self
        }
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
}
