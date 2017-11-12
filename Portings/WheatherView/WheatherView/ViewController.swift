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
import SwaggerClient
import CoreData

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
    
    lazy var managedObjectModel: NSManagedObjectModel? = {
        if let modelURL = Bundle.main.url(forResource: "DataModel", withExtension: "momd") {
            return NSManagedObjectModel(contentsOf: modelURL)
        } else {
            print("errrr")
        }
        return nil
    }()
    
    lazy var persistentContainer: NSPersistentContainer = {
        
        let container = NSPersistentContainer(name: "DataModel", managedObjectModel:managedObjectModel!)
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    func context() -> NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    @IBOutlet weak var chartView: LineChartView!
    
    @IBOutlet weak var pageSwitch: UISegmentedControl!
    @IBOutlet weak var statusLabel: UILabel!
    
    
    
    var lineChartEntry = [ChartDataEntry]()
    
    var ref: DatabaseReference?
    var list = [DataSnapshot]()
    var chartDataItems = [ChartDataEntry]()
    
    var listUpdatedAt = Date()
    
    var timer: Timer?
    
    var mostRecentItem: SimpleItem?
    
    
    @IBAction func tabChanged(_ sender: UISegmentedControl) {
        updateChartForLast24h(isTemperature: sender.selectedSegmentIndex == 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SimpleItem.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        SimpleItem.axisDateFormatter.dateFormat = "MMM d\n HH:mm"
        
        chartView.delegate = self
        
        updateData()
        setupRefreshTimer()
        
        ref = Database.database().reference(withPath: "records")
        
        //var i: Int = 0
        
        //        ref?.observe(.childAdded, with: { (snapshot) in
        //
        //            let item = SimpleItem(parentKey: snapshot.key,
        //                                  dictionary: snapshot.value as! [String : AnyObject])
        //
        //            guard
        //                let date = item.date,
        //                date > Calendar(identifier: .gregorian).startOfDay(for: Date().addingTimeInterval(-86400 * 2))
        //                else { return }
        //
        //            self.listUpdatedAt = Date()
        //            i += 1
        //
        //            guard
        //                let temp = item.temp
        //                else { return }
        //
        //            self.list.append(snapshot)
        //            self.chartDataItems.append(ChartDataEntry(x: date.timeIntervalSince1970, y: Double(temp)))
        //
        //
        //        })
        
        
    }
    
    func updateData() {
        
        let c = context()
        
        let fetchRequest = ListItem.fetchRequest() as NSFetchRequest<ListItem>
        let byDate = NSSortDescriptor(key: "date", ascending: true)
        fetchRequest.sortDescriptors = [byDate]
        
        var lastItem: ListItem?
        
        do {
            let list = try c.fetch(fetchRequest) as [ListItem]
            lastItem = list.last
        } catch {
            print("error----")
        }
        
        let date = lastItem?.date?.description ?? ""
        
        RecordAPI.list(print: ["pretty"], orderBy: "\"date\"", startAt: "\"\(date)\"") { (records, error) in
            for (key, value) in records ?? [:] {
                
                let item = ListItem(context: c)
                item.fireId = key
                item.co2 = value.co2 ?? 0
                item.temp = value.temp ?? 0
                if let date = value.date {
                    item.date = SimpleItem.dateFormatter.date(from: date)
                }
            }
            
            do {
                try c.save()
            } catch {
                print("error")
            }
            
            self.updateChartForLast24h(isTemperature: self.pageSwitch.selectedSegmentIndex == 0)
        }
        
    }
    
    func setupRefreshTimer() {
        
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true, block: { (t) in
            self.updateData()
        })
        
    }
    
    func updateChartForLast24h(isTemperature: Bool) {
        
        let c = context()
        
        let startDay = Calendar(identifier: .gregorian).startOfDay(for: Date())
        let predicate = NSPredicate(format: "date > %@", startDay as NSDate)
        
        let byDate = NSSortDescriptor(key: "date", ascending: true)
        
        let fetchRequest = ListItem.fetchRequest() as NSFetchRequest<ListItem>
        fetchRequest.sortDescriptors = [byDate]
        fetchRequest.predicate = predicate
        
        chartDataItems.removeAll()
        
        do {
            for item in try c.fetch(fetchRequest) as [ListItem] {
                
                guard
                    let date = item.date
                    else {
                        continue
                }
                let graphItem = ChartDataEntry(x: date.timeIntervalSince1970,
                                               y: isTemperature ? item.temp : item.co2)
                chartDataItems.append(graphItem)
            }
            
        } catch {
            print("error----")
        }
        
        
        let chartDataSet = LineChartDataSet(values: chartDataItems,
                                            label: isTemperature ? "Temperature (°C)" : "CO2 (ppm)")
        
        
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

