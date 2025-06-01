//
//  S3Service.swift
//  InsideMapsNikolaJocic
//
//  Created by Nikola Jočić on 31. 5. 2025..
//

import Foundation
import AWSS3
import Network

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
        checkInternetConnection { isConnected in
            if !isConnected {
                print("No internet connection. Saving file for retry...")

                self.saveFileForRetry(fileURL: fileURL, folderName: folderName, fileName: fileName, contentType: contentType) { saved in
                    if saved {
                        print("File saved locally for retry: \(fileName)")
                    } else {
                        print("Failed to save file for retry: \(fileName)")
                    }

                    let error = NSError(domain: "UploadError",
                                        code: -1009,
                                        userInfo: [NSLocalizedDescriptionKey: "Upload failed. No internet connection. File saved locally."])
                    completion(.failure(error))
                }

                return
            }
        }

        
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
                
                // Save file locally for retry if upload fails
                self.saveFileForRetry(fileURL: fileURL, folderName: folderName, fileName: fileName, contentType: contentType) { saved in
                    if saved {
                        print("Upload failed, but file saved for retry")
                    } else {
                        print("Upload failed and file was NOT saved for retry")
                    }
                    completion(.failure(error))
                }


                
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
    
    /// Checks if the device currently has an active internet connection
    func checkInternetConnection(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "InternetConnectionMonitor")

        monitor.pathUpdateHandler = { path in
            completion(path.status == .satisfied)
            monitor.cancel() // Stop monitoring after first response
        }

        monitor.start(queue: queue)
    }

    
    private func saveFileForRetry(fileURL: URL, folderName: String, fileName: String, contentType: String, completion: @escaping (Bool) -> Void) {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let retryFolder = cacheDir.appendingPathComponent("PendingUploads", isDirectory: true)

        do {
            try fileManager.createDirectory(at: retryFolder, withIntermediateDirectories: true)

            let destFileName = "\(folderName)__\(fileName)"
            let destURL = retryFolder.appendingPathComponent(destFileName)

            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }

            try fileManager.copyItem(at: fileURL, to: destURL)
            completion(true)
        } catch {
            print("Failed to save for retry: \(error)")
            completion(false)
        }
    }
    
    /// Uploads any files that were saved locally
    /// Called when the app starts
    func retryPendingUploads() {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let retryFolder = cacheDir.appendingPathComponent("PendingUploads", isDirectory: true)

        guard let fileURLs = try? fileManager.contentsOfDirectory(at: retryFolder, includingPropertiesForKeys: nil) else {
            print("Failed to read PendingUploads folder")
            return
        }

        for fileURL in fileURLs {
            let fileName = fileURL.lastPathComponent

            // Očekujemo format: Images__image1.jpg ili Logs__something.txt
            let components = fileName.split(separator: "__", maxSplits: 1).map(String.init)
            guard components.count == 2 else {
                print("Invalid filename format for retry: \(fileName)")
                continue
            }

            let folderName = components[0]
            let actualFileName = components[1]

            // ContentType možeš hardkodovati na osnovu foldera
            let contentType: String
            if folderName == s3FolderImages {
                contentType = "image/jpeg"
            } else if folderName == s3FolderLogs {
                contentType = "text/plain"
            } else {
                print("Unknown folder: \(folderName)")
                continue
            }

            print("Retrying upload for: \(actualFileName)")

            self.upload(fileURL: fileURL, folderName: folderName, fileName: actualFileName, contentType: contentType) { result in
                switch result {
                case .success:
                    try? fileManager.removeItem(at: fileURL)
                    print("Successfully retried and removed: \(actualFileName)")
                case .failure(let error):
                    print("Retry failed for \(actualFileName): \(error.localizedDescription)")
                    break
                }
            }
        }
    }

}
