//
//  ViewController.swift
//  TryCoreML
//
//  Created by Winston Hsieh on 12/12/2017.
//  Copyright © 2017 Winston Hsieh. All rights reserved.
//

import UIKit
import AVKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var resultLabel: UILabel!
    
    @IBOutlet weak var observeButtonOutlet: UIButton!
    
    var captureSession: AVCaptureSession!
    
    var observing:Bool = true
    
    var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        captureSession = AVCaptureSession()
        setupCapture()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: IBActions
    @IBAction func observeButtonPressed(_ sender: Any) {
        
        observing = !observing
        
        if (observing) {
            observeButtonOutlet.setTitle("Stop", for:.normal)
            startCapturing()
        } else {
            observeButtonOutlet.setTitle("Observe", for:.normal)
            stopCapturing()
        }
    }
    
    //MARK:
    func startCapturing() {
        captureSession.startRunning()
    }
    
    func stopCapturing() {
        captureSession.stopRunning()
    }
    
    func setupCapture() {
        
        let captureDevice = AVCaptureDevice.default(for: .video)
        
        guard let input = try? AVCaptureDeviceInput(device: captureDevice!) else { return }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.view.layer.addSublayer(previewLayer)
        previewLayer.frame = CGRect(x: 0.0, y: 0.0, width: self.view.frame.width, height: self.view.frame.height - 70)
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "captureQueue"))
        dataOutput.alwaysDiscardsLateVideoFrames = true
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        captureSession.sessionPreset = .photo
        captureSession.addInput(input)
        captureSession.addOutput(dataOutput)
        
        // make sure we are in portrait mode
        let conn = dataOutput.connection(with: .video)
        conn?.videoOrientation = .portrait
        
        self.startCapturing()
        
        guard let model = try? VNCoreMLModel(for: Resnet50().model) else { return }
        /*
        let request = VNCoreMLRequest(model: model) { (request, error) in
            if error != nil {
                print("error \(error!.localizedDescription)")
                return
            }
            
            print("request \(String(describing: request.results))")
            
            guard let result = request.results as? [VNClassificationObservation] else { return }
            
            guard let firstObservation = result.first else { return }
            
            DispatchQueue.main.async {
                let confidence = String(format: "%.2f", firstObservation.confidence * 100)
                
                self.resultLabel.text = "\(firstObservation.identifier, confidence)%"
            }
        }*/
        let classificationRequest = VNCoreMLRequest(model: model, completionHandler: handleClassifications)
        classificationRequest.imageCropAndScaleOption = .centerCrop
        
        visionRequests = [classificationRequest]
    }
    
    //MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("captured frame", Date())
        
        guard let cvPixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        connection.videoOrientation = .portrait
        
        try? VNImageRequestHandler(cvPixelBuffer: cvPixelBuffer, orientation: .upMirrored, options:[:]).perform(visionRequests)
    }
    
    func handleClassifications(request: VNRequest, error: Error?) {
        if let theError = error {
            print("Error: \(theError.localizedDescription)")
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        let classifications = observations[0...4] // top 4 results
            .flatMap({ $0 as? VNClassificationObservation })
            .flatMap({$0.confidence > 0.25 ? $0 : nil})
            .map({ "\($0.identifier) \(String(format:"%.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.resultLabel.text = classifications
        }
        
    }
}

