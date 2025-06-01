//
//  ImageCache.swift
//  InsideMapsNikolaJocic
//
//  Created by Nikola Jočić on 1. 6. 2025..
//

import UIKit

/// Using NSCache, with limits set to avoid memory pressure.
final class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
