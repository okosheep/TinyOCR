//
//  ViewController.swift
//  TinyOCR
//
//  Created by @okoshi on 2018/12/02.
//  Copyright © 2018 @okoshi. All rights reserved.
//

import UIKit
import AVFoundation
import Alamofire
import SwiftyJSON

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    /// カメラ
    @IBOutlet var cameraView: UIView!
    
    /// ステータスラベル
    @IBOutlet weak var statusLabel: UIBarButtonItem!
    
    /// シャッターボタン
    @IBOutlet weak var takeButton: UIBarButtonItem!
    
    /// キャプチャーセッション
    var captureSession: AVCaptureSession!
    
    /// 写真出力先
    var capturePhotoOutput: AVCapturePhotoOutput?
    
    /// プレビューレイヤー
    var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        captureSession = AVCaptureSession()
        capturePhotoOutput = AVCapturePhotoOutput()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice!)
            if (captureSession.canAddInput(captureDeviceInput)) {
                captureSession.addInput(captureDeviceInput)
                if (captureSession.canAddOutput(capturePhotoOutput!)) {
                    captureSession.addOutput(capturePhotoOutput!)
                    captureSession.startRunning()
                    
                    captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    captureVideoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
                    captureVideoPreviewLayer?.connection!.videoOrientation = AVCaptureVideoOrientation.portrait
                    
                    cameraView.layer.addSublayer(captureVideoPreviewLayer!)
                    
                    captureVideoPreviewLayer?.position = CGPoint(x: self.cameraView.frame.width/2, y: self.cameraView.frame.height/2)
                    captureVideoPreviewLayer?.bounds = cameraView.frame
                }
            }
        } catch {
            print(error)
        }
    }
    
    @IBAction func takePicture(_ sender: Any) {
        statusLabel.title = "処理中..."
        let capturePhotoSettings = AVCapturePhotoSettings()
        capturePhotoSettings.flashMode = .auto
        capturePhotoSettings.isAutoStillImageStabilizationEnabled = true
        capturePhotoSettings.isHighResolutionPhotoEnabled = false
        
        capturePhotoOutput!.capturePhoto(with: capturePhotoSettings, delegate: self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        statusLabel.title = "撮影しました"
        if let imageData = photo.fileDataRepresentation() {
            readText(imageData)
        }
    }
    
    fileprivate func readText(_ imageData: Data) {
        Alamofire.upload(imageData,
                         to: "https://japaneast.api.cognitive.microsoft.com/vision/v1.0/ocr?language=ja&detectOrientation=true",
                         method: .post,
                         headers: [
                            "Content-Type": "application/octet-stream",
                            "Ocp-Apim-Subscription-Key": "b6608b18db334f06a5cf52f7b3485ee9"
            ]).validate(statusCode: 200...226)
            .responseJSON { response in self.readTextResponse(response: response)
        }
    }
    
    fileprivate func readTextResponse(response: DataResponse<Any>) {
        guard let result = response.result.value else {
            statusLabel.title = "テキスト化失敗"
            return
        }
        statusLabel.title = "テキスト化完了"

        var text: String = ""
        let json = JSON(result)
        json["regions"].forEach { (_, region) in
            region["lines"].forEach { (_, line) in
                line["words"].forEach { (_, word) in
                    text.append(word["text"].string!)
                }
                text.append("\n")
            }
        }
        
        print(text)
        
        Alamofire.request("https://script.google.com/macros/s/AKfycbzRtRDLf_7w6SaXtNoG1-lBhp1ssKn_lLd0yipUuUM2FtB2E3I/exec",
                          method: .post,
                          parameters: ["text": text],
                          encoding: URLEncoding(destination: .methodDependent))
            .validate(statusCode: 200...226)
            .response { _ in self.statusLabel.title = "Google スプレッドシートに転送完了"
        }
    }
}

