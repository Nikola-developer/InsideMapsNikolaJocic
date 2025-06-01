//
//  ImagePreviewViewController.swift
//  InsideMapsNikolaJocic
//
//  Created by Nikola Jočić on 31. 5. 2025..
//

import Foundation
import UIKit

/// Displays preview of captured images, uploads them to S3, and generates a log
class ImagePreviewViewController: UIViewController {
    private let s3Service = S3Service()
    private let images: [UIImage]
    
    init(images: [UIImage]) {
        self.images = images
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    var onUpload: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let imagesStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()
    
    private let uploadButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Upload", for: .normal)
        button.addTarget(nil, action: #selector(handleUpload), for: .touchUpInside)
        return button
    }()
    
    private let dismissButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Dismiss", for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.addTarget(nil, action: #selector(handleDismiss), for: .touchUpInside)
        return button
    }()
    
    private let uploadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Uploading images, please wait"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .boldSystemFont(ofSize: 16)
        label.isHidden = true
        return label
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        for image in images {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 6
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 200),
                imageView.heightAnchor.constraint(equalToConstant: 200)
            ])
            imagesStackView.addArrangedSubview(imageView)
        }
        
        setupLayout()
    }
    
    private func setupLayout() {
        view.addSubview(imagesStackView)
        
        view.addSubview(uploadButton)
        view.addSubview(dismissButton)
        
        view.addSubview(uploadingLabel)
        view.addSubview(loadingIndicator)
        
        imagesStackView.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        
        uploadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imagesStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            imagesStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            uploadButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            uploadButton.bottomAnchor.constraint(equalTo: dismissButton.topAnchor, constant: -12),
            
            dismissButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dismissButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            
            uploadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            uploadingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: uploadingLabel.bottomAnchor, constant: 8)
        ])
    }
    
    @objc private func handleUpload() {
        imagesStackView.isHidden = true
        uploadButton.isHidden = true
        dismissButton.isHidden = true
        uploadingLabel.isHidden = false
        loadingIndicator.startAnimating()
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let id = UUID().uuidString.prefix(8)
        let suffixes = ["u", "n", "o"]
        var logLines: [String] = []
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        
        // DispatchGroup is used to coordinate multiple async uploads
        // Makes sure we know when all uploads are done before dismissing the screen.
        let dispatchGroup = DispatchGroup()
        
        // Uploading images
        for (index, image) in images.enumerated() {
            let fileName = "\(id)_\(suffixes[index]).jpg"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            guard let data = image.jpegData(compressionQuality: 0.9) else { continue }
            
            do {
                try data.write(to: fileURL)
                print("Saved locally: \(fileName)")
                
                logLines.append("\(fileName) - \(timestamp)")
                
                dispatchGroup.enter()
                
                s3Service.uploadImage(fileURL: fileURL, fileName: fileName) { result in
                    switch result {
                    case .success():
                        try? fileManager.removeItem(at: fileURL)
                    case .failure(let error):
                        print("AWS upload error: \(error)")
                    }
                    dispatchGroup.leave()
                }
                
            } catch {
                print("Error writing file: \(error)")
            }
        }
        
        // Creating and uploading log file
        let logName = "\(id)_log.txt"
        let logText = logLines.joined(separator: "\n")
        let logURL = tempDir.appendingPathComponent(logName)
        
        do {
            try logText.write(to: logURL, atomically: true, encoding: .utf8)
            
            dispatchGroup.enter()
            
            s3Service.uploadLog(fileURL: logURL, fileName: logName) { result in
                switch result {
                case .success():
                    try? fileManager.removeItem(at: logURL)
                case .failure(let error):
                    print("Log upload error: \(error)")
                }
                dispatchGroup.leave()
            }
        } catch {
            print("Failed to write log file: \(error)")
        }
        
            
        dispatchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { return }
            
            self.uploadingLabel.isHidden = true
            self.loadingIndicator.stopAnimating()
            self.uploadButton.isHidden = false
            self.dismissButton.isHidden = false
            
            self.onUpload?()
        }
    }
    
    
    @objc private func handleDismiss() {
        onDismiss?()
        dismiss(animated: true)
    }
}
