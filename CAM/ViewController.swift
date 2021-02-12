//
//  ViewController.swift
//  CAM
//
//  Created by paw on 10.02.2021.
//

import UIKit
import Photos
import AVFoundation

enum CaptureType {
    case photo
    case video
}


class ViewController: UIViewController {

    let cameraController = CameraController()
    var captureType: CaptureType = .video
    var isVideoCapturing: Bool {cameraController.isRecording}
    
    
    
    @IBOutlet weak var photoButton: UIButton!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var flipButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!
    @IBAction func captureAction(_ sender: Any) {
        switch captureType {
        case .photo:
            cameraController.captureImage {(image, error) in
                guard let image = image else {
                    print(error ?? "Image capture error")
                    return
                }
                
                try? PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
        case .video:
            cameraController.captureVideo()
                let alphaValue: CGFloat = isVideoCapturing ? 1 : 0
                let enable = isVideoCapturing
                
                
                flashButton.isEnabled = enable
                flipButton.isEnabled = enable
                photoButton.isEnabled = enable
                videoButton.isEnabled = enable
                UIView.animate(withDuration: 0.5) { [unowned self] in
                    flashButton.alpha = alphaValue
                    flipButton.alpha = alphaValue
                    videoButton.alpha = alphaValue
                    photoButton.alpha = alphaValue
                }

                if enable {
                    videoAction((Any).self)
                    AssetStore.play(AssetStore.recordStop)
                }else{
                    AssetStore.play(AssetStore.recordBegin)
                }
        }
    }
    @IBAction func flashAction(_ sender: Any) {
        if cameraController.flashMode == .on {
                cameraController.flashMode = .off
                flashButton.setBackgroundImage(UIImage(systemName: "bolt.slash.circle.fill"), for: .normal)
            }
         
            else {
                cameraController.flashMode = .on
                flashButton.setBackgroundImage(UIImage(systemName: "bolt.circle.fill"), for: .normal)
            }
    }
    @IBAction func flipAction(_ sender: Any) {
        do {
                try cameraController.switchCameras()
            }
            catch {
                print(error)
            }
            switch cameraController.currentCameraPosition {
            case .some(.front):
                flipButton.setBackgroundImage(UIImage(systemName: "faceid"), for: .normal)
            case .some(.rear):
                flipButton.setBackgroundImage(UIImage(systemName: "camera.viewfinder"), for: .normal)
            case .none:
                return
            }
    }
    @IBAction func photoAction(_ sender: Any) {
        captureType = .photo
        videoButton.isEnabled = true
        photoButton.isEnabled = false
        UIView.animate(withDuration: 0.3) { [unowned self] in
            captureButton.backgroundColor = .white
            videoButton.alpha = 1
            photoButton.alpha = 0.6
        }
    }
    @IBAction func videoAction(_ sender: Any) {
        captureType = .video
        photoButton.isEnabled = true
        videoButton.isEnabled = false
        UIView.animate(withDuration: 0.3) { [unowned self] in
            captureButton.backgroundColor = .systemRed
            photoButton.alpha = 1
            videoButton.alpha = 0.6
        }
    }
    override var prefersStatusBarHidden: Bool { return true }
    override func viewDidLoad() {
        super.viewDidLoad()
        if UIDevice.current.model == "iPad"{
            flashButton.isHidden = true
            print("iPad does not support flash mode")
        }
        captureButton.layer.cornerRadius = captureButton.bounds.height/2
        cameraController.prepare { [unowned self](error) in
            if let error = error {
                print(error)
            }
            try? self.cameraController.displayPreview(on: self.view)
        }
        videoButton.alpha = 0.6
        videoButton.isEnabled = false
    }
}
