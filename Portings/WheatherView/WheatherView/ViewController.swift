//
// ViewController.swift
// WheatherView
//
// Created by Andrey Pervushin on 26.10.2017.
// Copyright © 2017 Andrey Pervushin. All rights reserved.
//

import UIKit
import Charts
import FirebaseDatabase

class SimpleItem {
    static let dateFormatter = DateFormatter()
    static let axisDateFormatter = DateFormatter()
    
    var parentKey: String?
    
    var co2: Float?
    var date: Date?
    var temp: Float?
    
    init(parentKey: String, dictionary: [String : AnyObject]) {
        self.parentKey = parentKey
        
        if let co2 = dictionary["co2"] as? Float {
            self.co2 = Float(co2)
        }
        if let temp = dictionary["temp"] as? Float {
            self.temp = Float(temp)
        }
        if let date = dictionary["date"] as? String {
            
            self.date = SimpleItem.dateFormatter.date(from: date)
        }
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var chartView: LineChartView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var statusLabel: UILabel!
    var lineChartEntry = [ChartDataEntry]()
    
    var ref: DatabaseReference?
    var list = [DataSnapshot]()
    var chartDataItems = [ChartDataEntry]()
    
    var listUpdatedAt = Date()
    
    var timer: Timer?
    
    var mostRecentItem: SimpleItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SimpleItem.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        SimpleItem.axisDateFormatter.dateFormat = "MMM d\n HH:mm"
        
        chartView.delegate = self
        
        
        ref = Database.database().reference(withPath: "records")
        
        var i: Int = 0
        
        ref?.observe(.childAdded, with: { (snapshot) in
            
            let item = SimpleItem(parentKey: snapshot.key,
                                  dictionary: snapshot.value as! [String : AnyObject])
            
            guard
                let date = item.date,
                date > Calendar(identifier: .gregorian).startOfDay(for: Date().addingTimeInterval(-86400 * 7))
                else { return }
            
            self.listUpdatedAt = Date()
            i += 1
            
            guard
                let temp = item.temp
                else { return }
            
            self.list.append(snapshot)
            self.chartDataItems.append(ChartDataEntry(x: date.timeIntervalSince1970, y: Double(temp)))
            
            
        })
        
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { (t) in
            
            guard Date().timeIntervalSince(self.listUpdatedAt) > 1 else {
                return
            }
            
            if let lastSnapHot = self.list.last {
                
                let item = SimpleItem(parentKey: lastSnapHot.key,
                                      dictionary: lastSnapHot.value as! [String : AnyObject])
                self.updateLabel(item: item)
            }
            
            
            let chartDataSet = LineChartDataSet(values: self.chartDataItems, label: "Temperature (°C)")
            
            
            chartDataSet.colors = [.green]
            chartDataSet.circleRadius = 0
            chartDataSet.setCircleColor(.red)
            
            let chartData = LineChartData()
            chartData.addDataSet(chartDataSet)
            chartData.setDrawValues(true)
            
            //gradient fill
            let gradiantColors = [UIColor.cyan.cgColor, UIColor.clear.cgColor] as CFArray
            let colorLocations: [CGFloat] = [1.0, 0.0] //gradient position
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradiantColors, locations: colorLocations) else {
                print("gradient error!")
                return
            }
            chartDataSet.fill = Fill.fillWithLinearGradient(gradient, angle: 90)
            chartDataSet.drawFilledEnabled = true
            
            self.chartView.xAxis.valueFormatter = self
            self.chartView.xAxis.labelPosition = .bottom
            self.chartView.data = chartData
            self.chartView.notifyDataSetChanged()
            
        })
    }
    
    func updateLabel(item: SimpleItem) {
        
        var items = [String]()
        
        if let temp = item.temp {
            items.append(String(format: "temp: %0.1f°", temp))
        }
        if let co2 = item.co2 {
            items.append(String(format: "co2: %0.0fppm", co2))
        }
        
        self.statusLabel.text = items.joined(separator: "; ")
    }
    
}

extension ViewController: IAxisValueFormatter {
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSince1970: value)
        return SimpleItem.axisDateFormatter.string(from: date)
        
    }
    
}

extension ViewController: ChartViewDelegate {
    
    
}

