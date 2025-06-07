# InsideMaps Take-Home Assignment  - Nikola Jočić

  

This iOS application was built using ****Swift**** and ****UIKit**** as part of a take-home assignment. The app captures bracketed photos using the camera, allows users to preview and upload them to ****AWS S3****, and displays uploaded images in a ****lazy-loaded gallery****.
  
--- 

<table border="0" style="border: none;">
  <tr>
    <td valign="top" width="60%">

### Contents

- [Features](#features)  
- [Architecture](#architecture)  
- [Secrets & Configuration](#secrets--configuration)  
- [Design Decisions](#design-decisions)  
- [Offline functionality](#offline-functionality)  
- [Future Improvements](#future-improvements)  
- [App Screenshots](#app-screenshots)
</br>
This iOS application was built using **Swift** and **UIKit** 

</td>
    <td align="center" width="20%">
      <img src="https://github.com/user-attachments/assets/3dfb7e82-463e-44d9-aee1-773a84d77b9d" width="80%" alt="App Preview">
    </td>
  </tr>
</table>

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


## App Screenshots

<p align="center">
  <img alt="Launch view" src="https://github.com/user-attachments/assets/3dfb7e82-463e-44d9-aee1-773a84d77b9d" width="20%" />
  &nbsp;
  <img alt="Permission view"  src="https://github.com/user-attachments/assets/1c306d77-c565-4c1a-8689-d69241cea54e" width="20%" />
  &nbsp;
  <img alt="Camera view"  src="https://github.com/user-attachments/assets/e3321caa-46c7-4168-89f1-1d0169a69107" width="20%" />
  &nbsp;
  <img alt="Image view"  src="https://github.com/user-attachments/assets/8c7eb883-d504-4907-a67b-d6a789927a22" width="20%" />
</p>

<p align="center">
  <img alt="imagePreview_uploading view" src="https://github.com/user-attachments/assets/cb5e6134-a7f8-4208-8f7b-3f5194f76ec1" width="20%" />
  &nbsp;
  <img alt="gallery_while_loading_images view"  src="https://github.com/user-attachments/assets/4b052dd0-c154-496b-a5aa-dd2ad041b862" width="20%" />
  &nbsp;
  <img alt="gallery view"  src="https://github.com/user-attachments/assets/36081c3f-277d-4cff-8e97-052e7383dc14" width="20%" />
  &nbsp;
  <img alt="showing_error view"  src="https://github.com/user-attachments/assets/6b1f5c80-1c1b-4a60-a788-fbd7d2e05eaa" width="20%" />
</p>

---  
