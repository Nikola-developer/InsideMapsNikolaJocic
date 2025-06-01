//
//  CameraService.swift
//  InsideMapsNikolaJocic
//
//  Created by Nikola Jočić on 31. 5. 2025..
//

import AVFoundation
import UIKit

/// Contains all low-level camera logic using AVCaptureSession, including preview layer setup and bracketed image capture.
final class CameraService {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    func configureSession() {
        session.beginConfiguration()
        
        // Kamera
        if let input = input {
            session.removeInput(input)
        }
        
        // Using the default wide angle camera for general photo capture needs.
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            print("Can not add camera.")
            session.commitConfiguration()
            return
        }
        
        self.input = input
        session.addInput(input)
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }

    func attachPreview(to view: UIView) {
        if previewLayer != nil {
            previewLayer?.removeFromSuperlayer()
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    func startRunning() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopRunning() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func captureBracketed(delegate: AVCapturePhotoCaptureDelegate) {
        let settings = AVCapturePhotoBracketSettings(
            rawPixelFormatType: 0,
            processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg],
            bracketedSettings: [
                AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: -2),
                AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: 0),
                AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: 2)
            ]
        )

        settings.isLensStabilizationEnabled = photoOutput.isLensStabilizationDuringBracketedCaptureSupported
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
}
