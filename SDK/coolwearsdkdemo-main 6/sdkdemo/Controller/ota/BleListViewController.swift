//
//  BleListViewController.swift
//  ota2.0
//
//  Created by coolwear on 2022/8/10.
//

import UIKit
import BluetoothLibrary
//import ProgressHUD

class BleListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    typealias PeripheralBlock = (SearchPeripheral, Int) -> Void
    
    var tableView: UITableView!
    var data: Array<SearchPeripheral>!
    let k6 = CEProductK6.shareInstance()!
    

    var selectBlock: PeripheralBlock?
    var sp: SearchPeripheral?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(bleStatus(noti:)), name: NSNotification.Name(ProductStatusChangeNoticeKey), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveData(noti:)), name: NSNotification.Name(ScanPeripheralsNoticeKey), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiceInfo(noti:)), name: NSNotification.Name(CEProductK6ReceiveDataNoticeKey), object: nil)
        initUI()
        search()
    }
    
    @objc func receiveData(noti: Notification) {
        
        let arr: Array = noti.object as! Array<SearchPeripheral>
        let result = arr.sorted(by: {(obj1: SearchPeripheral, obj2: SearchPeripheral) -> Bool in
            return labs(obj1.rssi?.intValue ?? 0) < labs(obj2.rssi?.intValue ?? 0)
        })
        data = result
        tableView.reloadData()
        
    }
    
    @objc func receiceInfo(noti: NSNotification) {
        
        if noti.userInfo == nil { return }
        
        let data: [AnyHashable : Any] = noti.userInfo!["Data"] as! [AnyHashable : Any]

        let items: Int = data["items"] as! Int
        
        let idstr: NSNumber = data["customer_id"] as! NSNumber
        var cid: Int = idstr.intValue
        if items > 11 {
            let idhstr: NSNumber = data["customer_id_h"] as! NSNumber
            cid = idhstr.intValue << 8 + cid
        }
        
        //获取到id再退出
        selectBlock?(sp!, cid)
        dismiss(animated: false)
    }
    
    @objc func bleStatus(noti: Notification) {
        ProgressHUD.dismiss()
        let sta: ProductStatus = ProductStatus(rawValue: (noti.object as! NSNumber).intValue) ?? .none
        if sta == ProductStatus.completed {
            let cmd = CE_RequestDevInfoCmd()
            CEProductK6.shareInstance().sendCmd(toDevice: cmd, complete: nil)
        }
    }
    
    
    func initUI() {
        
        view.backgroundColor = .systemBlue
        
        let height = view.bounds.size.height
        var areaTop: CGFloat = height > 811 ? 34 : 20;
        areaTop += 20;
        
        let topView = UIView(frame: CGRect(x: 0, y: areaTop, width: view.bounds.size.width, height: 44))
        view.addSubview(topView)
        
        let backBtn = UIButton()
        backBtn.frame = CGRect(x: 10, y: 7, width: 24, height: 30)
        backBtn.setImage(UIImage(named: "返回"), for: .normal)
        backBtn.addTarget(self, action: #selector(back), for: .touchUpInside)
        topView.addSubview(backBtn)
        
        tableView = UITableView(frame: CGRect(x: 0, y: topView.frame.origin.y + topView.frame.height, width: view.bounds.size.width, height: view.bounds.size.height-44), style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = nil
        tableView.rowHeight = 50
        view.addSubview(tableView)
    }
    
    func search() {
        k6.startScan()
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 2.0) {
            self.k6.stopScan()
            DispatchQueue.main.async { self.tableView.reloadData() }
        }
    }
    
    @objc func back() {
        dismiss(animated: true)
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (data != nil) ? data.count : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: "bleListCell")
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "bleListCell")
        }
        let model: SearchPeripheral = data[indexPath.row]
        let name = model.name() ?? "null"
        let idstr = model.deviceID() ?? "null"
        cell?.textLabel?.text = name + "【\(idstr)】"
        let rssi = model.rssi?.intValue ?? 0
        cell?.detailTextLabel?.text = rssi == 0 ? "Connected" : "\(String(describing: rssi))";
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let model: SearchPeripheral = data[indexPath.row]
        let alrt = UIAlertController(title: "", message: "Connecting Device【\(model.name() ?? "null")】", preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel", style: .default)
        let sure = UIAlertAction(title: "Connecting", style: .default) { action in
            ProgressHUD.show()
            self.sp = model
            self.k6.connect(model.peripheral)
        }
        alrt.addAction(cancel)
        alrt.addAction(sure)
        present(alrt, animated: false)
    }
    
    deinit {
        print("😄😄😄😄😄😄 BleListViewController deinit")
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
