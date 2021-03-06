//
//  ViewController.swift
//  ibeacon
//
//  Created by Zahra on 1/14/19.
//

import UIKit
import CoreLocation
import Foundation

var A=1.0
var H=1.0
var C=1.0
var r=1.0
var q=1.0
var d=0.0
var p=0.0
var gain=0.0
var x=1.0
var first = true
var BeaconsList = [CLBeacon]()
var Xout = Double()
var Yout = Double()

class ViewController: UIViewController ,CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.initLocating()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initLocating() {
        if CLLocationManager.isRangingAvailable() {
            self.locationManager.requestWhenInUseAuthorization()
            self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            self.locationManager.allowsBackgroundLocationUpdates = true
            self.locationManager.delegate = self
        }
    }
   
    ///////////////////////////////////////////////////////////////
    
    func startLocating() {
        self.locationManager.startUpdatingLocation()
        self.rangeBeacons()
    }
    
    ////////////////////////////////////////////////////////////////
    
    func rangeBeacons() {
        let uuid = UUID(uuidString :"2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6")!
        let region = CLBeaconRegion(proximityUUID: uuid, identifier: "beacon")
        locationManager.startRangingBeacons(in: region)
    }
    
    ////////////////////////////////////////////////////////////////
    
    func getDefaultBeacons() -> [(UUID, CLBeaconMajorValue, CLBeaconMinorValue, Int, Int)] { // [(uuid, major, minor, x, y)]
        let DefaultBeacons : [(UUID, CLBeaconMajorValue, CLBeaconMinorValue, Int, Int)] = [
            ( UUID(uuidString :"2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6")!, CLBeaconMajorValue(1), CLBeaconMinorValue(0), 0 , 0 ),
            ( UUID(uuidString :"2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6")!, CLBeaconMajorValue(1), CLBeaconMinorValue(1), 10, 0 ),
            ( UUID(uuidString :"2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6")!, CLBeaconMajorValue(1), CLBeaconMinorValue(2), 0 , 5 ),
            ( UUID(uuidString :"2F234454-CF6D-4A0F-ADF2-F4911BA9FFA6")!, CLBeaconMajorValue(1), CLBeaconMinorValue(3), 10, 5 ) ]
        return DefaultBeacons
    }
    
    ////////////////////////////////////////////////////////////////
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            rangeBeacons()
        }
    }
    
    ////////////////////////////////////////////////////////////////
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        
        guard (beacons.first?.proximity) != nil else { print("Couldn't find the beacon!"); return }
        // var DefaultBeacons = getDefaultBeacons()
        
        for b in beacons {
            if !BeaconsList.contains(b) {
                BeaconsList.append(b)
            }
        }
        BeaconsList.sorted(by: { $0.rssi > $1.rssi }) // or proximity /// nemidunam chejuri 10 ta rssi
                                                                      /// az ye beacon ro begiram zakhire konam :((
        
        
        
    }
    
    ////////////////////////////////////////////////////////////////
    
    func average( X : [Int], n : Int ) -> Double{
        
        var sum = 0
        for i in 0...n {
            sum += X[i]
        }
        return Double(sum/n)
    }
    
    ////////////////////////////////////////////////////////////////
    
    func std( X : [Int], n : Int ) -> Double {
        
        let ave = average(X: X, n: n)
        var sum : Double = 0.0
        for i in 1...n {
            sum += pow((Double(X[i]) - ave), 2)
        }
        return sqrt(Double(sum/Double(n-1)))
    }
    
    ////////////////////////////////////////////////////////////////
    
    func find_distance( rssi_p : Double, rssi_c : Double) -> Double{
        
        if rssi_p >= rssi_c {
            return pow(10, rssi_p/rssi_c)
        }
        else {
            return 0.9 * pow(7.71, rssi_p/rssi_c)
        }
    }
    
    ////////////////////////////////////////////////////////////////
    
    func kalman_filter( dist : Double ) -> Double{
        
        if first {
            x = Double(dist)/C
            p = r/(C*C)
            first = false
        }
        else {
            d = A*x
            p = A*A*p+q
            gain = (p*H)/(p*H*H+r)
            p = (1 - gain*H)*p
            d += gain*(Double(dist)-H*d)
        }
        return d
    }
    
    ////////////////////////////////////////////////////////////////
    
    func mean(X : [Double], Y : [Double]) -> (Double,Double){
        
        // m0 = A+B/2 , m1 = B+C/2 , m2 = A+C/2
        // A,m1 --> y-yA = (m1y - yA/m1x - xA)(x-xA) , B,m2 --> ...
        // y = y => x?
        
        let A = ((Y[2]+Y[0]/2) - Y[1]) / ((X[2]+X[0]/2) - X[1])
        let B = ((Y[1]+Y[2]/2) - Y[0]) / ((X[1]+X[2]/2) - X[0])
        let x = (A - B)*(A * X[1] - B * X[0])
        let y = A*(x - X[1]) + Y[1]
        
        return (x,y)
    }
    
    ////////////////////////////////////////////////////////////////
    
    func triangulation( x : [Double],
                        y : [Double],
                        d : [Double]){
        
        var a, dx, dy, D, h, rx, ry : Double
        var Xh, Yh : Double
        var xi, yi : Double
        
        var xarray = [Double]()
        var yarray = [Double]()
        
        for i in 0...3 {
            
            dx = x[(i+1)%3] - x[i]
            dy = y[(i+1)%3] - y[i]
            D = sqrt(dy*dy + dx*dx)
            
            guard D < (d[i] + d[(i+1)%3]) else{
                /* no solution. circles do not intersect. */
                return
            }
            guard D > fabs(d[i] - d[(i+1)%3]) else {
                /* no solution. one circle is contained in the other */
                return
            }
            
            var a1 = (d[i]*d[i] - d[(i+1)%3]*d[(i+1)%3] + D*D)
            a = a1 / (2.0 * D)
            
            /* Determine the coordinates of point 2. */
            Xh = x[i] + (dx * a/D)
            Yh = y[i] + (dy * a/D)
            
            /* Determine the distance from point 2 to either of the
             * intersection points.
             */
            h = sqrt(a*a - d[i]*d[i])
            
            /* Now determine the offsets of the intersection points from
             * point 2.
             */
            rx = -dy * (h/D)
            ry = dx * (h/D)
            
            /* Determine the absolute intersection points. */
            
            if abs(pow(y[2] - Xh + rx, 2) - pow(x[2] - Xh + rx, 2)) <=
                abs(pow(y[2] - Xh - rx, 2) - pow(x[2] - Xh - rx, 2)) {
                xi = Xh + rx
                yi = Yh + ry
            }
            else {
                xi = Xh - rx
                yi = Yh - ry
            }
            
            xarray[i] = xi
            yarray[i] = yi
        }
        
        (Xout, Yout) = mean(X : xarray, Y : yarray) // markaze mosalas
    }
    
    ////////////////////////////////////////////////////////////////
    
    func main(){
        
        var ave : Double ,varians : Double
        var Distance : [Double] = [0,0,0]
        var RSSI_p : Double
        var Dist : Double
        var count = 0
        var RSSI : [Int]
        
        /* for i in 0...3{
         ave = average(X : RSSI, n : 10)
         varians = std(X : RSSI, n : 10)
         for i in 0...10{
         if Double(RSSI[i]) < (ave - 2*varians){
         RSSI.remove(at: i)
         count += 1
         }
         }
         RSSI_p = average( X : RSSI, n : count)
         Dist = find_distance( rssi_p : RSSI_p, rssi_c : -6)
         
         Distance[i] = kalman_filter( dist : Dist)
         }
         */
        
        // call triangulation ba x,y beacon hayi ke nazdikemun budan + Distance
        // repeat :)
        
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
}
