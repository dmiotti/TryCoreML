//
//  ViewController.swift
//  TestCoreML
//
//  Created by David Miotti on 06/06/2017.
//  Copyright © 2017 MuxuMuxu. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision
import CoreTelephony

/// Main view controller
final class CameraVC: UIViewController {

    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var switchMLBarBtn: UIBarButtonItem!

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session.queue")
    private let mlQueue = DispatchQueue(label: "ml.queue")
    private let model = AppMLModel()
    private var isAnalysing: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.text = "Waiting"
        previewView.session = session
        ensureAuthorizationStatus()
        configureInterfaceBasedOnModelType()
        sessionQueue.async {
            do {
                try self.prepareCameraDevice()
            } catch let error {
                self.showMessage(error.localizedDescription)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { self.session.startRunning() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sessionQueue.async { self.session.stopRunning() }
    }

    @IBAction func switchMLModel(_ sender: Any) {
        let alert = UIAlertController(title: "Choose ML model", message: nil, preferredStyle: .actionSheet)
        let googLeNetPlacesAction = UIAlertAction(title: "GoogLeNetPlaces", style: .default) { _ in
            self.model.modelType = .googLeNetPlaces
            self.configureInterfaceBasedOnModelType()
        }
        let inceptionAction = UIAlertAction(title: "Inceptionv3", style: .default) { _ in
            self.model.modelType = .inceptionv3
            self.configureInterfaceBasedOnModelType()
        }
        let resnet50Action = UIAlertAction(title: "Resnet50", style: .default) { _ in
            self.model.modelType = .resnet50
            self.configureInterfaceBasedOnModelType()
        }
        let vgg16Action = UIAlertAction(title: "VGG16", style: .default) { _ in
            self.model.modelType = .vgg16
            self.configureInterfaceBasedOnModelType()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(googLeNetPlacesAction)
        alert.addAction(inceptionAction)
        alert.addAction(resnet50Action)
        alert.addAction(vgg16Action)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    private func ensureAuthorizationStatus() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                self.sessionQueue.resume()
            }
        default:
            break
        }
    }

    /// Thread safe method to show an error
    ///
    /// - Parameter message: The error message to be shown
    private func showMessage(_ message: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.showMessage(message) }
            return
        }
        self.textView.text = message
    }

    private func configureInterfaceBasedOnModelType() {
        let type = model.modelType
        switch type {
        case .googLeNetPlaces:  switchMLBarBtn.title = "GoogLeNetPlaces"
        case .inceptionv3:      switchMLBarBtn.title = "Inceptionv3"
        case .resnet50:         switchMLBarBtn.title = "Resnet50"
        case .vgg16:            switchMLBarBtn.title = "VGG16"
        }
    }

    private func prepareCameraDevice() throws {
        session.beginConfiguration()

        guard session.canSetSessionPreset(.photo) else {
            throw NSError(domain: AppName, code: -1, userInfo: [NSLocalizedDescriptionKey: "Can't set High session preset"])
        }
        session.sessionPreset = .photo

        let availableDevices: [AVCaptureDevice.DeviceType] = [.builtInDualCamera, .builtInTelephotoCamera, .builtInWideAngleCamera]
        let foundDevice = availableDevices.first { AVCaptureDevice.default($0, for: .video, position: .back) != nil }
        guard let device = foundDevice, let videoDevice = AVCaptureDevice.default(device, for: .video, position: .back) else {
            throw NSError(domain: AppName, code: -1, userInfo: [NSLocalizedDescriptionKey: "Can't find video device input"])
        }
        let deviceInput = try AVCaptureDeviceInput(device: videoDevice)

        guard session.canAddInput(deviceInput) else {
            throw NSError(domain: AppName, code: -1, userInfo: [NSLocalizedDescriptionKey: "Can't add device input to session"])
        }
        session.addInput(deviceInput)

        DispatchQueue.main.async {
            let statusBarOrientation = UIApplication.shared.statusBarOrientation
            var initialVideoOrientation = AVCaptureVideoOrientation.portrait
            if statusBarOrientation != .unknown, let orientation = AVCaptureVideoOrientation(rawValue: statusBarOrientation.rawValue) {
                initialVideoOrientation = orientation
            }

            if let previewLayer = self.previewView.layer as? AVCaptureVideoPreviewLayer {
                previewLayer.connection?.videoOrientation = initialVideoOrientation
            }
        }

        let videoOuput = AVCaptureVideoDataOutput()
        videoOuput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        guard session.canAddOutput(videoOuput) else {
            throw NSError(domain: AppName, code: -1, userInfo: [NSLocalizedDescriptionKey: "Can't add video output to session"])
        }
        session.addOutput(videoOuput)

        session.commitConfiguration()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let deviceOrientation = UIDevice.current.orientation

        if UIDeviceOrientationIsPortrait( deviceOrientation ) || UIDeviceOrientationIsLandscape( deviceOrientation ),
            let previewLayer = self.previewView.layer as? AVCaptureVideoPreviewLayer,
            let videoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue) {

            previewLayer.connection?.videoOrientation = videoOrientation
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isAnalysing, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        mlQueue.async { self.processImage(pixelBuffer: pixelBuffer) }
    }

    private func processImage(pixelBuffer: CVPixelBuffer) {
        isAnalysing = true

        do {
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: 6)

            let vnModel = try VNCoreMLModel(for: self.model.model.model)
            let request = VNCoreMLRequest(model: vnModel, completionHandler: { (vnRequest, error) in
                self.isAnalysing = false
                guard let results = vnRequest.results as? [VNClassificationObservation] else {
                    self.showMessage(error?.localizedDescription ?? "Unable to get results from VNCoreMLRequest")
                    return
                }

                let classifications = results
                    .filter({ $0.confidence > 0.002 })
                    .map({
                        let confidence = String(format: "%.4f", $0.confidence)
                        return "\($0.identifier)(\(confidence))"
                    }).joined(separator: "\n")

                self.showMessage(classifications)
            })
            request.imageCropAndScaleOption = VNImageCropAndScaleOptionScaleFill

            try requestHandler.perform([request])

        } catch let error {
            showMessage(error.localizedDescription)
        }

        isAnalysing = false
    }
}
