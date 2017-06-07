//
//  MLModel.swift
//  TestCoreML
//
//  Created by David Miotti on 07/06/2017.
//  Copyright © 2017 Wopata. All rights reserved.
//

import UIKit

final class AppMLModel {
    private let resnet50Model = Resnet50()
    private let vgg16Model = VGG16()
    private let inceptionModel = Inceptionv3()
    private let googLeNetPlaces = GoogLeNetPlaces()

    enum ModelType {
        case googLeNetPlaces
        case inceptionv3
        case resnet50
        case vgg16

        var imageSize: CGSize {
            switch self {
            case .inceptionv3:
                return CGSize(width: 299, height: 299)
            case .resnet50, .vgg16, .googLeNetPlaces:
                return CGSize(width: 224, height: 224)
            }
        }
    }

    var modelType: ModelType = .googLeNetPlaces
    var model: ImagePredictionModel {
        switch modelType {
        case .inceptionv3:  return inceptionModel
        case .resnet50:     return resnet50Model
        case .vgg16:        return vgg16Model
        case .googLeNetPlaces: return googLeNetPlaces
        }
    }

    /// Crop the image to match ML requirements with correct size
    ///
    /// - Parameter pixelBuffer: The pixel buffer to resize
    /// - Returns: A new CVPixelBuffer
    func prepareImage(pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let imageSize = modelType.imageSize
        let cropRect = CGRect(x: (CGFloat(width) - imageSize.width) / 2.0,
                              y: (CGFloat(height) - imageSize.height) / 2.0,
                              width: imageSize.width,
                              height: imageSize.height)

        let croppedImage = CIImage(cvPixelBuffer: pixelBuffer)
            .cropping(to: cropRect)
            .applyingOrientation(6)

        let ciContext = CIContext(options: nil)

        let filter = CIFilter(name: "CIAffineTransform")
        let transform = CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY)
        filter?.setValue(transform, forKey: "inputTransform")
        filter?.setValue(croppedImage, forKey: "inputImage")

        guard let outputImage = filter?.outputImage, let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            throw NSError(domain: AppName, code: -1, userInfo: [NSLocalizedDescriptionKey: "Can't apply cropping"])
        }
        let cropped = CIImage(cgImage: cgImage)

        let newPixelBuffer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)

        CVPixelBufferCreate(kCFAllocatorDefault,
                            Int(imageSize.width),
                            Int(imageSize.height),
                            kCVPixelFormatType_32BGRA,
                            nil, newPixelBuffer)

        if let pixelBuffer = newPixelBuffer.pointee {
            let ciContext = CIContext(options: nil)
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            ciContext.render(cropped, to: pixelBuffer)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return pixelBuffer
        } else {
            throw NSError(domain: AppName, code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot generate pixel buffer"])
        }
    }
}
