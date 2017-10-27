//
//  ViewController.swift
//  WheatherView
//
//  Created by Andrey Pervushin on 26.10.2017.
//  Copyright © 2017 Andrey Pervushin. All rights reserved.
//

import UIKit
import Charts
import FirebaseDatabase

class SimpleItem {
    static let dateFormatter = DateFormatter()
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SimpleItem.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        
        chartView.delegate = self
        
        ref = Database.database().reference(withPath: "records")
        
        ref?.observe(.childAdded, with: { (snapshot) in
            self.list.append(snapshot)
            let item = SimpleItem(parentKey: snapshot.key,
                                  dictionary: snapshot.value as! [String : AnyObject])
            
            var items = [String]()
            
            if let temp = item.temp {
                items.append(String(format: "temp: %0.1f°", temp))
            }
            if let co2 = item.co2 {
                items.append(String(format: "co2: %0.0fppm", co2))
            }
            
            self.statusLabel.text = items.joined(separator: "; ")
        })
        
    }

}

extension ViewController: ChartViewDelegate {
    
    
}

