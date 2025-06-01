# InsideMaps Take-Home Assignment  - Nikola Jočić

  

This iOS application was built using ****Swift**** and ****UIKit**** as part of a take-home assignment. The app captures bracketed photos using the camera, allows users to preview and upload them to ****AWS S3****, and displays uploaded images in a ****lazy-loaded gallery****.
  
---  

## Features

- ****Camera capture**** with 3 bracketed exposures (-2, 0, +2 EV)

- ****Camera permission handling**** with fallback screen

- ****Image preview**** before uploading

- ****AWS S3 upload**** of images and a log file

- ****Gallery view**** with infinite scroll and lazy loading

- ****Image caching**** using `NSCache`

---

## Architecture

- UIKit + Programmatic UI

-  `CameraService` – handles AVCapture configuration

- `S3Service` – AWS S3 upload and pagination

- `ImageCache` – lightweight memory caching
  
---

## Secrets & Configuration

Sensitive data like AWS access keys are not hardcoded.
They are defined in `.xcconfig` and exposed to the app via `Info.plist`.
`S3Service` reads when configurin AWS.

`Secrets.xcconfig`:

```text

AWS_ACCESS_KEY = ...

AWS_SECRET_KEY = ...
```

`S3Service`:

```Swift  

private func configureAWS() {
guard
    let accessKey = Bundle.main.object(forInfoDictionaryKey: "AWS_ACCESS_KEY") as? String,
    let secretKey = Bundle.main.object(forInfoDictionaryKey: "AWS_SECRET_KEY") as? String
else {
    fatalError("AWS keys not found in Info.plist")
}
```
## Design Decisions

-   `AVCapturePhotoBracketSettings`  was used to support bracketed exposure capturing.
    
-   `UICollectionView`  with  `UICollectionViewFlowLayout`  was used to present the gallery in a grid-style layout.
    
-   `NSCache`  was chosen for image caching because it's memory-aware and auto-purges on pressure.

-   `AWSS3` SDK library was chosen because it’s the official Amazon library for working with S3

----------

## Offline functionality

Added offline capability to `S3Service`.

-   If the user does not have an internet connection at the time of the upload, the files are automatically saved locally in the PendingUploads directory.
    
-   On application launch, the S3Service checks for files that have not been uploaded and tries to send them to S3 again.

- This functionality allows the user to use the application smoothly even when there is no Internet.

----------

## Future Improvements

-   Add error feedback to user using  `UIAlertController`
-   Show image upload progress
-   Add gallery filtering or image metadata
-   Offline-first caching strategy
