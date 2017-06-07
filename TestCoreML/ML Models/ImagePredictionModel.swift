//
//  ImagePredictionModel.swift
//  TestCoreML
//
//  Created by David Miotti on 07/06/2017.
//  Copyright © 2017 Wopata. All rights reserved.
//

import UIKit

protocol ImagePredictionOutput {
    var classLabel: String { get }
    var classLabelProbs: [String : Double] { get }
}

protocol ImagePredictionModel {
    func prediction(from pixelBuffer: CVPixelBuffer) throws -> ImagePredictionOutput
}

extension GoogLeNetPlacesOutput: ImagePredictionOutput {
    var classLabel: String {
        return sceneLabel
    }

    var classLabelProbs: [String : Double] {
        return sceneLabelProbs
    }
}
extension Resnet50Output: ImagePredictionOutput { }
extension VGG16Output: ImagePredictionOutput { }
extension Inceptionv3Output: ImagePredictionOutput { }

extension GoogLeNetPlaces: ImagePredictionModel {
    func prediction(from pixelBuffer: CVPixelBuffer) throws -> ImagePredictionOutput {
        return try prediction(sceneImage: pixelBuffer)
    }
}

extension Inceptionv3: ImagePredictionModel {
    func prediction(from pixelBuffer: CVPixelBuffer) throws -> ImagePredictionOutput {
        return try prediction(image: pixelBuffer)
    }
}

extension Resnet50: ImagePredictionModel {
    func prediction(from pixelBuffer: CVPixelBuffer) throws -> ImagePredictionOutput {
        return try prediction(image: pixelBuffer)
    }
}

extension VGG16: ImagePredictionModel {
    func prediction(from pixelBuffer: CVPixelBuffer) throws -> ImagePredictionOutput {
        return try prediction(image: pixelBuffer)
    }
}
