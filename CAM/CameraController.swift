//
//  CameraController.swift
//  CAM
//
//  Created by paw on 10.02.2021.
//

import UIKit
import AVFoundation
class AssetStore{
    static let shot = getAssetFromBundle(withResourseName: "shot", withExtension: "m4a")
    static let recordBegin = getAssetFromBundle(withResourseName: "record_begin", withExtension: "m4a")
    static let recordStop = getAssetFromBundle(withResourseName: "record_stop", withExtension: "m4a")
    
    static func getAssetFromBundle(withResourseName name: String, withExtension extension: String) -> AVAsset{
        guard let path = Bundle.main.path(forResource: name, ofType: `extension`) else {fatalError()}
        let url = URL(fileURLWithPath: path)
        return AVAsset(url: url)
    }
    static func play(_ asset: AVAsset){
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.play()
    }
}


enum CameraControllerError: Swift.Error {
    case captureSessionAlreadyRunning
    case captureSessionIsMissing
    case inputsAreInvalid
    case invalidOperation
    case noCamerasAvailable
    case unknown
}




public enum CameraPosition {
    case front
    case rear
}

class CameraController: NSObject{
    
    var previewLayer = AVCaptureVideoPreviewLayer()
    var movieOutput = AVCaptureMovieFileOutput()
    var flashMode = AVCaptureDevice.FlashMode.on
    var captureSession: AVCaptureSession?
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    var isRecording: Bool {movieOutput.isRecording}
    

    func captureVideo() {
        guard let captureSession = captureSession, captureSession.isRunning else { return }
        let settings = AVCapturePhotoSettings()
        if UIDevice.current.model == "iPhone"{
        settings.flashMode = self.flashMode
        }
        if movieOutput.isRecording {
        movieOutput.stopRecording()
        } else {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileUrl = path.appendingPathComponent("CAM_VIDEO.mov")
            do{
                try FileManager.default.removeItem(at: fileUrl)
            }
            catch{
                print((error as NSError).localizedFailureReason as Any, (error as NSError).localizedDescription)
            }
            movieOutput.startRecording(to: fileUrl, recordingDelegate: self)
        }
        
    }
    
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = captureSession, captureSession.isRunning else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
        let settings = AVCapturePhotoSettings()
        if UIDevice.current.model == "iPhone"{
        settings.flashMode = self.flashMode
        }
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        AssetStore.play(AssetStore.shot)
        self.photoCaptureCompletionBlock = completion
    }
    
    func switchCameras() throws {
        func switchToFrontCamera() throws {
            guard let inputs = captureSession?.inputs, let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput),
                  let frontCamera = self.frontCamera, let captureSession = captureSession else { throw CameraControllerError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.removeInput(rearCameraInput)
            
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
                
                self.currentCameraPosition = .front
            }
            
            else { throw CameraControllerError.invalidOperation }
        }
        func switchToRearCamera() throws {
            guard let inputs = captureSession?.inputs, let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput),
                  let rearCamera = self.rearCamera, let captureSession = captureSession else { throw CameraControllerError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            captureSession.removeInput(frontCameraInput)
            
            if captureSession.canAddInput(self.rearCameraInput!) {
                captureSession.addInput(self.rearCameraInput!)
                
                self.currentCameraPosition = .rear
            }
            
            else { throw CameraControllerError.invalidOperation }
        }
        
        //5
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        //6
        captureSession.beginConfiguration()
        
        //7
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
            
        case .rear:
            try switchToFrontCamera()
        }
        
        //8
        captureSession.commitConfiguration()
    }
//    func displayVideoPreview(on view: UIView) throws {
//        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
//
//        self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        self.videoPreviewLayer!.videoGravity = .resizeAspectFill
//        self.videoPreviewLayer!.connection?.videoOrientation = .portrait
//
//        previewLayer.removeFromSuperlayer()
//        view.layer.insertSublayer(self.videoPreviewLayer!, at: 0)
//        self.videoPreviewLayer!.frame = view.frame
//    }
    
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer.videoGravity = .resizeAspectFill
        self.previewLayer.connection?.videoOrientation = .portrait
        
//        videoPreviewLayer?.removeFromSuperlayer()
        view.layer.insertSublayer(self.previewLayer, at: 0)
        self.previewLayer.frame = view.frame
    }
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        func configureCaptureDevices() throws {
            //1
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInMicrophone], mediaType: .video, position: .unspecified)
            let cameras = (session.devices.compactMap { $0 })
            if cameras.isEmpty { throw CameraControllerError.noCamerasAvailable }
            
            //2
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
            
        }
        func configureDeviceInputs() throws {
            //3
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            let audioInput = AVCaptureDevice.default(for: AVMediaType.audio)
            try captureSession.addInput(AVCaptureDeviceInput(device: audioInput!))
            //4
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
                
                self.currentCameraPosition = .rear
            }
            
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
                else { throw CameraControllerError.inputsAreInvalid }
                
                self.currentCameraPosition = .front
            }
            
            
            else { throw CameraControllerError.noCamerasAvailable }
        }
        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            
            if captureSession.canAddOutput(self.photoOutput!) { captureSession.addOutput(self.photoOutput!) }
            if captureSession.canAddOutput(movieOutput) {
                captureSession.addOutput(movieOutput)
            }
            captureSession.startRunning()
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
            
            catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    if let error = error {
    self.photoCaptureCompletionBlock?(nil, error)
    } else if let imageData = photo.fileDataRepresentation(), let photo = UIImage(data: imageData) {
    self.photoCaptureCompletionBlock?(photo, nil)
    } else {
    self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
    }
    }
}

extension CameraController : AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?){
        if error == nil {
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
        }
    }
}
