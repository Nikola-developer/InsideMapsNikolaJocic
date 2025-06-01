//
//  S3Service.swift
//  InsideMapsNikolaJocic
//
//  Created by Nikola Jočić on 31. 5. 2025..
//

import Foundation
import AWSS3

/// Handles all AWS S3 interactions:
/// configuring AWS
/// uploading files
/// listing files
/// generating signed URLs
final class S3Service {
    
    var s3Bucket = "im-devtest"
    var s3Prefix = "nikola.jocic"
    
    // Using different folders for images an log files
    var s3FolderImages = "Images"
    var s3FolderLogs = "Logs"
    
    var continuationToken: String?
    var isFinishedPaging = false
    
    init() {
        configureAWS()
    }
    
    // Using Secrets.xcconfig to avoid hardcoding secrets
    // Load AWS credentials securely from Info.plist
    private func configureAWS() {
        guard
            let accessKey = Bundle.main.object(forInfoDictionaryKey: "AWS_ACCESS_KEY") as? String,
            let secretKey = Bundle.main.object(forInfoDictionaryKey: "AWS_SECRET_KEY") as? String
        else {
            fatalError("AWS keys not found in Info.plist")
        }
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: accessKey,
            secretKey: secretKey
        )
        
        let configuration = AWSServiceConfiguration(
            region: .USEast1,
            credentialsProvider: credentialsProvider
        )
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    
    func uploadImage(fileURL: URL, fileName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        upload(fileURL: fileURL, folderName: s3FolderImages, fileName: fileName, contentType: "image/jpeg", completion: completion)
    }
    
    func uploadLog(fileURL: URL, fileName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        upload(fileURL: fileURL, folderName: s3FolderLogs, fileName: fileName, contentType: "text/plain", completion: completion)
    }
    
    /// Uploads file s3
    /// Used by "uploadImage" and "uploadLog"
    private func upload(fileURL: URL, folderName: String, fileName: String, contentType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let expression = AWSS3TransferUtilityUploadExpression()
        let transferUtility = AWSS3TransferUtility.default()
        
        transferUtility.uploadFile(
            fileURL,
            bucket: s3Bucket,
            key: "\(s3Prefix)/\(folderName)/\(fileName)",
            contentType: contentType,
            expression: expression
        ) { task, error in
            if let error = error {
                print("Upload error: \(error)")
                completion(.failure(error))
            } else {
                print("Uploaded: \(fileName)")
                completion(.success(()))
            }
        }
    }
    
    func fetchNextPage(completion: @escaping ([URL]) -> Void) {
        guard !isFinishedPaging else {
            completion([])
            return
        }
        
        let s3 = AWSS3.default()
        let listRequest = AWSS3ListObjectsV2Request()!
        listRequest.bucket = s3Bucket
        listRequest.prefix = "\(s3Prefix)/\(s3FolderImages)"
        listRequest.maxKeys = 10
        listRequest.continuationToken = continuationToken
        
        s3.listObjectsV2(listRequest).continueWith { task in
            var urls: [URL] = []
            
            if let error = task.error {
                print("Error: \(error)")
                DispatchQueue.main.async { completion([]) }
                return nil
            }
            
            guard let result = task.result else {
                DispatchQueue.main.async { completion([]) }
                return nil
            }
            
            self.continuationToken = result.nextContinuationToken
            self.isFinishedPaging = result.nextContinuationToken == nil
            
            let imageKeys = result.contents?.compactMap { obj -> String? in
                guard let key = obj.key, key.hasSuffix(".jpg") else { return nil }
                return key
            } ?? []
            
            
            
            let group = DispatchGroup()
            for key in imageKeys {
                group.enter()
                self.getSignedURL(for: key.replacingOccurrences(of: "\(self.s3Prefix)/\(self.s3FolderImages)/", with: "")) { url in
                    if let url = url {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                completion(urls)
            }
            
            return nil
        }
    }
    
    
    func getSignedURL(for fileName: String, completion: @escaping (URL?) -> Void) {
        let request = AWSS3GetPreSignedURLRequest()
        request.bucket = s3Bucket
        request.key = "\(s3Prefix)/\(s3FolderImages)/\(fileName)"
        request.httpMethod = .GET
        request.expires = Date().addingTimeInterval(3600) // 1 sat
        
        let preSignedURLBuilder = AWSS3PreSignedURLBuilder.default()
        
        preSignedURLBuilder.getPreSignedURL(request).continueWith { task in
            if let error = task.error {
                print("Signed URL error: \(error)")
                completion(nil)
            } else if let url = task.result {
                completion(url as URL)
            } else {
                completion(nil)
            }
            return nil
        }
    }
}

