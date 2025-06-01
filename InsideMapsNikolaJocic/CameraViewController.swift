//
//  CameraViewController.swift
//  InsideMapsNikolaJocic
//
//  Created by Nikola Jočić on 30. 5. 2025..
//

import UIKit
import AVFoundation

/// Main screen where users take pictures.
/// Uses CameraService and responds to user interaction.
final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    private let cameraService = CameraService()
    private var capturedImages: [UIImage] = []
    
    private let captureButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 2
        return button
    }()
    
    private let galleryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFill
        button.clipsToBounds = true
        button.layer.cornerRadius = 8
        button.backgroundColor = .white
        return button
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        cameraService.configureSession()
        cameraService.attachPreview(to: view)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        capturedImages = []
        cameraService.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraService.stopRunning()
    }
    
    private func setupUI() {
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(captureButton)
        view.addSubview(galleryButton)
        
        NSLayoutConstraint.activate([
            // Capture dugme centrirano
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            // Gallery dugme skroz desno, sa razmakom 20
            galleryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            galleryButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            galleryButton.widthAnchor.constraint(equalToConstant: 50),
            galleryButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        
        captureButton.addTarget(self, action: #selector(capturePressed), for: .touchUpInside)
        galleryButton.addTarget(self, action: #selector(openGallery), for: .touchUpInside)
    }
    
    @objc private func capturePressed() {
        capturedImages = []
        cameraService.captureBracketed(delegate: self)
    }
    
    @objc private func openGallery() {
        let galleryVC = GalleryViewController()
        navigationController?.pushViewController(galleryVC, animated: true)
    }
    
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("Error: \(error)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("Can not convert image.")
            return
        }
        
        capturedImages.append(image)
        
        if capturedImages.count == 3 {
            DispatchQueue.main.async {
                let previewVC = ImagePreviewViewController(images: self.capturedImages)
                previewVC.onUpload = { [weak self] in
                    previewVC.dismiss(animated: true) {
                        let galleryVC = GalleryViewController()
                        self?.navigationController?.pushViewController(galleryVC, animated: true)
                    }
                }
                self.present(previewVC, animated: true)
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
}


