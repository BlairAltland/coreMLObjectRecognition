//
//  ViewController.swift
//  CoreMLObjectRecognition
//
//  Created by Blair Altland on 6/9/17.
//  Copyright © 2017 Blair Altland. All rights reserved.
//

import UIKit
import MobileCoreServices
import Vision
import CoreML
import AVKit

class ViewController: UIViewController {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var resultLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        beginAVCaptureSession()
    }

    fileprivate func setBackgroundToCameraView(layer: CALayer) {
        cameraView.layer.addSublayer(layer)
        layer.frame = cameraView.bounds
        cameraView.bringSubview(toFront: resultLabel)
    }
    
    fileprivate func beginAVCaptureSession() {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
        let input = try! AVCaptureDeviceInput(device: backCamera)
        
        captureSession.addInput(input)
        
        let cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        setBackgroundToCameraView(layer: cameraPreviewLayer)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate"))
        videoOutput.recommendedVideoSettings(forVideoCodecType: .jpeg, assetWriterOutputFileType: .mp4)
        
        captureSession.addOutput(videoOutput)
        captureSession.sessionPreset = .high
        captureSession.startRunning()
    }
    
    fileprivate func predict(image: CGImage) {
        let model = try! VNCoreMLModel(for: VGG16().model)
        let request = VNCoreMLRequest(model: model, completionHandler: didGetPredictionResults)
        let handler = VNImageRequestHandler(cgImage: image)
        try! handler.perform([request])
    }
    
    fileprivate func didGetPredictionResults(request: VNRequest, error: Error?) {
        //create results
        guard let results = request.results as? [VNClassificationObservation] else {
            resultLabel.text = "🚨😱🚨"
            return
        }
        
        //if the model returns no results
        guard results.count != 0 else {
            resultLabel.text = "🚨😱🚨"
            return
        }
        
        guard let observations = request.results as? [VNClassificationObservation]
            else { fatalError("unexpected result type from VNCoreMLRequest") }
        guard let best = observations.first
            else { fatalError("can't get best result") }
        
        resultLabel.text = "\(best.identifier) -- \(best.confidence)"
    }


}

//Handles the camera capture (AKA AVCapture)
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { fatalError("pixel buffer is nil") }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { fatalError("cg image") }
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)
        
        DispatchQueue.main.sync {
            predict(image: uiImage.cgImage!)
        }
    }
}
