//
//  GalleryImageCell.swift
//  InsideMapsNikolaJocic
//
//  Created by Nikola Jočić on 31. 5. 2025..
//

import UIKit

/// Custom UICollectionViewCell that displays an image, either from cache or fetched from a URL.
final class GalleryImageCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let fallbackImage = UIImage(named: "logo-text")
    private var currentURL: URL?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.image = fallbackImage
        
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with url: URL) {
        currentURL = url
        
        // Load image from cache if availible
        if let cached = ImageCache.shared.image(for: url) {
            imageView.image = cached
            imageView.contentMode = .scaleAspectFill
            return
        }
        
        // Load image from s3 if cache is not availible
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data),
                  self.currentURL == url else { return }
            
            // Cache image
            ImageCache.shared.setImage(image, for: url)
            
            DispatchQueue.main.async {
                self.imageView.image = image
                self.imageView.contentMode = .scaleAspectFill
            }
        }.resume()
    }
}
