/*
 
 ViewController.swift
 Variometer
 
 The MIT License (MIT)
 
 Copyright (c) 2018 Türkay Biliyor
 
 */

import UIKit
import MapKit
import AVFoundation
import CoreMotion // Make sure CoreMotion is imported

extension Double {
    private static let arc4randomMax = Double(UInt32.max)
    
    static func random0to1() -> Double {
        return Double(arc4random()) / arc4randomMax
    }
}

enum MapType: NSInteger {
    case StandardMap = 0
    case SatelliteMap = 1
    case HybridMap = 2
}

class ViewController: UIViewController ,MKMapViewDelegate, CLLocationManagerDelegate{
    
    var pressure: Double = 0.0
    var altitude: Double = 0.0
    var rAltitude: Double = 0.0
    var oldaltitude: Double = 0.0
    var vario: Double = 0.0
    var seaLevel: Double = 101325.0
    var toneFrequency: Double = 700.0
    var myLocations: [CLLocation] = []
    
    var KF_VAR_ACCEL : Double = 0.0075
    var KF_VAR_MEASUREMENT : Double = 0.05
    var KalmanEnable : Bool =  true
    
    var start: DispatchTime = DispatchTime.now()
    var end: DispatchTime = DispatchTime.now()
  
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var altLabel: UILabel!
    @IBOutlet weak var variometerLable: UILabel! // Vario Label
    @IBOutlet weak var mapView: MKMapView!
    private var locationManager: CLLocationManager!
    private var currentLocation: CLLocation?
    
    lazy var altimeter = CMAltimeter() // Lazily load CMAltimeter
    var kalmanFilter = KalmanFilter()
    var varioDelay = PieceviseLinearFunction()
    var varioTone = PieceviseLinearFunction()
    
    var timer: DispatchSourceTimer?
    
    //fix orientation to portrait
    private var orientations = UIInterfaceOrientationMask.portrait
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        get { return self.orientations }
        set { self.orientations = newValue }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        varioDelay.addNewPoint(newPoint: xyPoint(x: 0, y: 0.4763))
        varioDelay.addNewPoint(newPoint: xyPoint(x: 0.441, y: 0.3619))
        varioDelay.addNewPoint(newPoint: xyPoint(x: 1.029, y: 0.2238))
        varioDelay.addNewPoint(newPoint: xyPoint(x: 1.559, y: 0.1565))
        varioDelay.addNewPoint(newPoint: xyPoint(x: 2.471, y: 0.0985))
        varioDelay.addNewPoint(newPoint: xyPoint(x: 3.571, y: 0.0741))
        
        varioTone.addNewPoint(newPoint: xyPoint(x: 0, y: toneFrequency))
        varioTone.addNewPoint(newPoint: xyPoint(x: 0.25, y: toneFrequency + 100))
        varioTone.addNewPoint(newPoint: xyPoint(x: 1.0, y: toneFrequency + 200))
        varioTone.addNewPoint(newPoint: xyPoint(x: 1.5, y: toneFrequency + 300))
        varioTone.addNewPoint(newPoint: xyPoint(x: 2.0, y: toneFrequency + 400))
        varioTone.addNewPoint(newPoint: xyPoint(x: 3.5, y: toneFrequency + 500))
        varioTone.addNewPoint(newPoint: xyPoint(x: 4.0, y: toneFrequency + 600))
        varioTone.addNewPoint(newPoint: xyPoint(x: 4.5, y: toneFrequency + 700))
        varioTone.addNewPoint(newPoint: xyPoint(x: 6.0, y: toneFrequency + 800))
        
        kalmanFilter.start(x_accel: KF_VAR_ACCEL)
        
        startAltimeter()
        startGpsMap()
        startBeep()
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func exitPressed(_ sender: Any) {
        stopBeep()
        stopAltimeter()
        stopGpsMap()
        exit(0);
    }
    
    /////gps/////
    func startGpsMap() {
        
        self.mapView.delegate = self
        self.mapView.mapType = .standard
        self.mapView.showsUserLocation = true
        self.mapView.showsScale = true
        self.mapView.showsCompass = true
        
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.headingFilter = 5
        self.locationManager.headingOrientation = .portrait
        
        // Check for Location Services
        
        if CLLocationManager.locationServicesEnabled() {
            self.locationManager.requestWhenInUseAuthorization()
            self.locationManager.startUpdatingLocation()
            self.locationManager.startUpdatingHeading()
        }
    }
    
    func stopGpsMap () {
        locationManager.stopUpdatingLocation();
    }
    
    func ZoomToCoordinateAndCenter (coordinate: CLLocationCoordinate2D , meters: Double , animate: Bool)
    {
        let lastRegion = MKCoordinateRegionMakeWithDistance(coordinate, meters, meters)
        mapView.setRegion(lastRegion, animated: animate)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let location = locations.last else {
            return
        }
        
        // singleton for get last(current) location
        self.currentLocation = location
        myLocations.append(location)
        
        if (myLocations.count > 1){
            let sourceIndex = myLocations.count - 1
            let destinationIndex = myLocations.count - 2
            
            let c1 = myLocations[sourceIndex].coordinate
            let c2 = myLocations[destinationIndex].coordinate
            var a = [c1, c2]
            let polyline = MKPolyline(coordinates: &a, count: a.count)
            self.mapView.add(polyline)
        }
        
        if(location.speed >= 0 && location.altitude >= 0)
        {
            self.speedLabel.text = String(format: "%.0f km/h", location.speed * 3.6)
            self.altLabel.text =  String(format: "%.01f m", location.altitude)
            //self.mapView.camera.heading = location.course
            //self.mapView.setCamera(mapView.camera, animated: true)
        }
        
        self.mapView.userTrackingMode = .followWithHeading
        
    }
    
    func getRadius(centralLocation: CLLocation) -> Double{
        let topCentralLat:Double = centralLocation.coordinate.latitude -  mapView.region.span.latitudeDelta/2
        let topCentralLocation = CLLocation(latitude: topCentralLat, longitude: centralLocation.coordinate.longitude)
        let radius = centralLocation.distance(from: topCentralLocation)
        return radius
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error \(error)")
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer{
        assert(overlay is MKPolyline, "overlay must be polyline")
        
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        polylineRenderer.strokeColor = UIColor.blue
        polylineRenderer.lineWidth = 3
        return polylineRenderer
    }
    
    @IBAction func mapTypeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case MapType.StandardMap.rawValue:
            mapView.mapType = .standard
        case MapType.SatelliteMap.rawValue:
            mapView.mapType = .satellite
        case MapType.HybridMap.rawValue:
            mapView.mapType = .hybrid
        default:
            break
        }
    }
    
    ////sensor///
    
    func startAltimeter() {
        
        // Check if altimeter feature is available
        if (CMAltimeter.isRelativeAltitudeAvailable()) {
            
            print("Variometer Starting.")
            self.start = DispatchTime.now()
            self.end = DispatchTime.now()
           
            // Start altimeter updates, add it to the main queue
            self.altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main, withHandler: { (altitudeData:CMAltitudeData?, error:Error?) in
                
                if (error != nil) {
                    // If there's an error, stop updating and alert the user
                  
                    self.stopAltimeter()
                    if #available(iOS 8, *) {
                        let alertController = UIAlertController(title: "Error", message: error!.localizedDescription, preferredStyle: .alert)
                        //We add buttons to the alert controller by creating UIAlertActions:
                        let actionOk = UIAlertAction(title: "OK",
                                                     style: .default,
                                                     handler: nil) //You can use a block here to handle a press on this button
                        
                        alertController.addAction(actionOk)
                        self.present(alertController, animated: true, completion: nil)
                    }
                    else {
                    let alertView = UIAlertView(title: "Error", message: error!.localizedDescription, delegate: nil, cancelButtonTitle: "OK")
                    alertView.show()
                    }
                    
                } else {
                    //self.altitude = altitudeData!.relativeAltitude.doubleValue   // Relative altitude in meters
                    self.pressure = altitudeData!.pressure.doubleValue        // Pressure in kilopascals
                    self.rAltitude = altitudeData!.relativeAltitude.doubleValue
                    self.calculateVario()
                 }
            })
            
        } else {
            if #available(iOS 8, *) {
                let alertController = UIAlertController(title: "Error", message: "Barometer not available on this device.", preferredStyle: .alert)
                //We add buttons to the alert controller by creating UIAlertActions:
                let actionOk = UIAlertAction(title: "OK",
                                             style: .default,
                                             handler: nil) //You can use a block here to handle a press on this button
                
                alertController.addAction(actionOk)
                self.present(alertController, animated: true, completion: nil)
            }
            else {
                let alertView = UIAlertView(title: "Error", message: "Barometer not available on this device.", delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
            }
        }
        
    }
    
    func stopAltimeter() {
        AudioGenerator.sharedSynth().engineStop()
        self.altLabel.text = "-"
        self.altimeter.stopRelativeAltitudeUpdates() // Stop updates
        print("Variometer Stopped.")
    }
    
    func startBeep() {
        
        let queue = DispatchQueue(label: "timer", attributes: .concurrent)
        timer?.cancel()        // cancel previous timer if any
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: .seconds(0), leeway: .milliseconds(100))
        
        timer?.setEventHandler {
            [weak self] in // `[weak self]` only needed if you reference `self` in this closure and you want to prevent strong reference cycle
            
            if((self?.vario)! < Double(0.2)){
                return
            }
            let seconds = self?.varioDelay.getValue(x: (self?.vario)!)
            let frequency:Float32 = Float32(self!.varioTone.getValue(x: self!.vario))
            AudioGenerator.sharedSynth().play(carrierFrequency: frequency);
            usleep(useconds_t( 1000 * 1000 * seconds!))
            AudioGenerator.sharedSynth().stop()
            usleep(useconds_t( 1000 * 1000 * seconds! ))
        }
        timer?.resume()
    }
    
    private func stopBeep() {
        timer?.cancel()
        timer = nil
    }
    
    func calculateVario() {
        
        if(self.oldaltitude == 0.0) {
            self.oldaltitude = self.rAltitude
        }
        
        self.end = DispatchTime.now()
        if(self.end >= self.start)
        {
            let nanoTime = self.end.uptimeNanoseconds - self.start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
            let diff = Double(nanoTime) / 1_000_000_000
            
            if(self.KalmanEnable)
            {
                self.kalmanFilter.Update(z_abs: self.rAltitude, var_z_abs: KF_VAR_MEASUREMENT, dt: diff)
                self.vario = Double(kalmanFilter.GetXVel())
                print(String(format: "GetXAbs %.1f GetXVel %.1f", kalmanFilter.GetXAbs(),kalmanFilter.GetXVel()))
            }
            else
            {
                self.vario = Double((self.rAltitude - self.oldaltitude) / diff)
                self.oldaltitude = self.rAltitude
            }
            
            self.variometerLable.text = String(format: "%.1f m/sn", self.vario)
            self.start = self.end
        }
       
        /* other alternate for getting alt diff
         
        let Pa = self.pressure * 1000
        self.altitude = 44330.0 * (1.0 - pow(Pa / seaLevel, 0.19))

        if(self.oldaltitude == 0.0) {
        self.oldaltitude = self.altitude
        }
        self.vario = Double((altitude - oldaltitude) / diff)
        self.variometerLable.text = String(format: "%.1f / %.1f", self.vario,self.rAltitude)
        oldaltitude = altitude
         */
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

