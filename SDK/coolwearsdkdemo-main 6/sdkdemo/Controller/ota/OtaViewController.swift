//
//  ViewController.swift
//  ota2.0
//
//  Created by coolwear on 2022/8/10.
//

import UIKit
import BluetoothLibrary
import CoreTelephony
import CallKit
import SnapKit

class OtaViewController: UIViewController, CXCallObserverDelegate {

    var fileView: UIView!
    var fileTitleLab: UILabel!
    var fileLabel: UILabel!
    var upgradeBtn: UIButton!
    var versionLab: UILabel!
    
    private let callObserver = CXCallObserver()
    private var status: ProductStatus = .none
    private var sp: SearchPeripheral?
    
    var fileVC: FileListViewController?
    @objc var customerId: Int = 0
    
    private var fileData: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initUI()
        
        UIApplication.shared.isIdleTimerDisabled = true
        addCallObserver()
       
        view.backgroundColor = .white
        NotificationCenter.default.addObserver(self, selector: #selector(receiveData(noti:)), name: NSNotification.Name(CEProductK6ReceiveDataNoticeKey), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bleStatus(noti:)), name: NSNotification.Name(ProductStatusChangeNoticeKey), object: nil)
        
        
        let fileTap = UITapGestureRecognizer(target: self, action: #selector(chooseFile))
        fileView.addGestureRecognizer(fileTap)
        
        upgradeBtn.layer.cornerRadius = 8
        upgradeBtn.addTarget(self, action: #selector(startUpgrade), for: .touchUpInside)
        
        let dic: [String: Any] = Bundle.main.infoDictionary!
        let version = dic["CFBundleVersion"] as! String
        versionLab.textAlignment = .center
        versionLab.textColor = .systemBlue
        versionLab.text = "Version: " + version
    }

    private func initUI(){
        
        fileView = UIView()
        fileView.backgroundColor = .white
        view.addSubview(fileView)
        
        fileTitleLab = UILabel()
        fileTitleLab.text = "File"
        fileView.addSubview(fileTitleLab)
        
        fileLabel = UILabel()
        fileLabel.text = "choose"
        fileView.addSubview(fileLabel)
        
        upgradeBtn = UIButton()
        upgradeBtn.setTitle("To upgrade", for: .normal)
        upgradeBtn.backgroundColor = UIColor.blue
        upgradeBtn.addTarget(self, action: #selector(startUpgrade), for: .touchUpInside)
        view.addSubview(upgradeBtn)
        
        versionLab = UILabel()
        versionLab.font = UIFont(descriptor: UIFontDescriptor(), size: 12)
        versionLab.textColor = .lightText
        view.addSubview(versionLab)
    }
    
    override func viewWillLayoutSubviews() {
    
        
        fileView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaInsets.top)
            make.left.right.equalTo(view)
            make.height.equalTo(44)
        }
        
        fileTitleLab.snp.makeConstraints { make in
            make.centerY.equalTo(fileView)
            make.left.equalTo(15)
        }
        
        fileLabel.snp.makeConstraints { make in
            make.right.equalTo(-15)
            make.centerY.equalTo(fileView)
        }
        
        upgradeBtn.snp.makeConstraints { make in
            make.top.equalTo(fileView.snp.bottom).offset(20)
            make.left.equalTo(25)
            make.right.equalTo(-25)
            make.height.equalTo(50)
        }
        
        versionLab.snp.makeConstraints { make in
            make.top.equalTo(upgradeBtn.snp.bottom).offset(12)
            make.centerX.equalTo(upgradeBtn)
        }
        
    }
    

    @objc func chooseFile() {
        
        if fileVC != nil {
            fileVC?.customerId = customerId
            present(fileVC!, animated: false)
            return
        }
        
        let vc = FileListViewController()
        vc.customerId = customerId
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: false)
        vc.downloadBlock = { name, data in
            self.fileLabel.text = name
            self.fileData = data
        }
        fileVC = vc
    }
    
    @objc func startUpgrade() {
        
        if fileData == nil { return }
        
        let alert = UIAlertController(title: nil, message: "Now to upgrade", preferredStyle: .alert)
        let act1 = UIAlertAction(title: "Cancel", style: .default)
        let act2 = UIAlertAction(title: "Upgrade", style: .default) { act in
            let cmd = CE_RequestOTAStatusCmd()
            CEProductK6.shareInstance().sendCmd(toDevice: cmd, complete: nil)
        }
        alert.addAction(act1)
        alert.addAction(act2)
        present(alert, animated: false)
    }
    

    
    @objc func receiveData(noti: Notification) {
        
        if noti.userInfo == nil { return }
        
        let recvData: [AnyHashable : Any] = noti.userInfo! as [AnyHashable : Any]
        let typeObj: NSNumber = recvData["DataType"] as! NSNumber

        if typeObj.intValue == 201 {
            startTransmittingData(infoData: recvData)
        }
        
    }
    
    func startTransmittingData(infoData: [AnyHashable : Any]) {
        
        let cmd = CE_SendOtaDataCmd(data: fileData, otaStatusInfo: infoData, deviceInfo: [:]) { p in
            if p < 1.0 {
                ProgressHUD.showProgress(p)
            }else{
                ProgressHUD.dismiss()
            }
        }
        CEProductK6.shareInstance().sendCmd(toDevice: cmd, complete: nil)
    }
    
    private func addCallObserver() {
        self.callObserver.setDelegate(self, queue: DispatchQueue.main)
    }
    
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        
        if call.hasConnected {
            print("接通电话")
        }else if call.hasEnded {
//            startUpgrade()
        }
        
    }
    
    @objc func bleStatus(noti: Notification) {
        ProgressHUD.dismiss()
        status = ProductStatus(rawValue: (noti.object as! NSNumber).intValue) ?? .none
        if (status == .completed) {
            self .startUpgrade()
        }
    }
}

