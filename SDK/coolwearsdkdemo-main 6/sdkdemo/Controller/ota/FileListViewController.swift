//
//  FileListViewController.swift
//  ota2.0
//
//  Created by coolwear on 2022/8/10.
//

import UIKit
import SwiftyJSON

class FileListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let bar = UIView()
    private let serverView = UIView()
    private let idView = UIView()
    private let findView = UIView()
    private let findBtn = UIButton()
    private let infLab = UILabel()
    private var tableView: UITableView!
    private let serverLab = UILabel()
    private let titleLabel = UILabel()
    private let backBtn = UIButton()
    private let idTextFild = UITextField()
    
    private var local: Int = 1
    private var versionData: [OtaVersionModel] = []
    private var openIdx: Int = 0
    
    var customerId: Int = 0
    private var cid: Int = 0
    
    typealias FileBlock = (String, Data) -> Void
    var downloadBlock: FileBlock?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        idTextFild.text = "\(customerId)"
        loadData()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    private func initUI() {
        
        view.backgroundColor = .systemBlue
        
        let width = view.bounds.size.width
        let height = view.bounds.size.height
        var areaTop: CGFloat = height > 811 ? 34 : 20;
        areaTop += 20;
        bar.frame = CGRect(x: 0, y: areaTop, width: width, height: 44)
        serverView.frame = CGRect(x: 0, y: maxY(view: bar), width: width, height: 49)
        serverView.backgroundColor = .white
        
        idView.frame = CGRect(x: 0, y: maxY(view: serverView)+1, width: width, height: 49)
        idView.backgroundColor = .white
        
        findView.frame = CGRect(x: 0, y: maxY(view: idView), width: width, height: 65)
        findView.backgroundColor = .white

        infLab.frame = CGRect(x: 0, y: maxY(view: findView), width: width, height: 36)
        infLab.backgroundColor = .white
        infLab.textAlignment = .center
        
        view.addSubview(bar)
        view.addSubview(serverView)
        view.addSubview(idView)
        view.addSubview(findView)
        view.addSubview(infLab)
        
        let maxY = self.maxY(view: infLab)
        tableView = UITableView(frame: CGRect(x: 0, y: maxY, width: view.bounds.size.width, height: view.bounds.size.height-maxY), style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.showsVerticalScrollIndicator = false
        tableView.register(FileListCell.self, forCellReuseIdentifier: "FileListCell")
        tableView.rowHeight = 56
        view.addSubview(tableView)
        
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
        
        initSubUI()
        bindAction()
    }
    
    private func maxY(view: UIView) -> CGFloat {
        return view.frame.origin.y + view.frame.size.height
    }
    
    private func initSubUI() {
        
        let width = view.bounds.size.width
        
        titleLabel.text = "Download"
        titleLabel.textColor = .white
        titleLabel.frame = bar.bounds
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title3)
        bar.addSubview(titleLabel)
        
        backBtn.frame = CGRect(x: 10, y: 7, width: 24, height: 30)
        backBtn.setImage(UIImage(named: "返回"), for: .normal)
        backBtn.addTarget(self, action: #selector(back), for: .touchUpInside)
        bar.addSubview(backBtn)
                
        let sLab = UILabel()
        sLab.frame = CGRect(x: 15, y: 0, width: 100, height: serverView.frame.size.height)
        sLab.text = "Server"
        serverView.addSubview(sLab)
        
        let leftW = sLab.frame.size.width + 15
        serverLab.frame = CGRect(x: leftW, y: 0, width: width-leftW - 16, height: serverView.frame.size.height)
        serverLab.textAlignment = .right
        serverLab.textColor = .lightGray
        serverLab.text = getService()
        serverView.addSubview(serverLab)
        
        let idLeft = UILabel()
        idLeft.frame = CGRect(x: 15, y: 0, width: leftW, height: serverView.frame.size.height)
        idLeft.text = "Entry ID:"
        idView.addSubview(idLeft)
        
        idTextFild.frame = CGRect(x: leftW, y: 0, width: width-leftW - 16, height: idView.frame.size.height)
        idTextFild.textAlignment = .right
        idTextFild.textColor = .lightGray
        idTextFild.keyboardType = .numberPad
        idView.addSubview(idTextFild)
  
        findBtn.frame = CGRect(x: 15, y: 8, width: width-30, height: 49)
        findBtn.backgroundColor = .systemBlue
        findBtn.layer.cornerRadius = 8
        findBtn.setTitle("Find", for: .normal)
        findView.addSubview(findBtn)
        
    }
    
    private func getService() -> String {
        return local == 1 ? "Cloud" : "Local"
    }
    
    private func ip() -> String {
        let remoteIp = "http://tool.ota.coolwear.fit:9200/Ota/VersionList?customerId="
        let localIp = "http://192.168.101.117:9200/Ota/VersionList?customerId="
        let ip = local == 1 ? remoteIp : localIp
        return ip + "\(customerId)"
    }
    
    private func bindAction() {
        
        backBtn.addTarget(self, action: #selector(back), for: .touchUpInside)
        findBtn.addTarget(self, action: #selector(findAction), for: .touchUpInside)
        
        serverLab.isUserInteractionEnabled = true
        let serTap = UITapGestureRecognizer(target: self, action: #selector(changeServer))
        serverLab.addGestureRecognizer(serTap)
        
        idTextFild.addTarget(self, action: #selector(startEntryID(tf:)), for: .editingDidBegin)
        idTextFild.addTarget(self, action: #selector(endEntryID(tf:)), for: .editingDidEnd)
        
    }
    
    @objc func startEntryID(tf: UITextField) {
        idTextFild.text = ""
    }
    
    @objc func endEntryID(tf: UITextField) {
        if tf.text?.count == 0 {
            tf.text = "\(customerId)"
        }
    }
    
    @objc func findAction() {
        loadData()
    }
    
    private func loadData() {
        
        let inputId: Int = Int(idTextFild.text!) ?? 0
        if customerId != inputId {
            versionData = []
            tableView.reloadData()
            customerId = inputId
        }
        requestFile(hud: true)
    }
    
    @objc func requestFile(hud: Bool) {
        
        view.endEditing(true)
        
        if hud { ProgressHUD.show() }
        
      
        AF.request(ip(), method: .get) { urlReq in
            urlReq.timeoutInterval = 5
            urlReq.allowsConstrainedNetworkAccess = false
        }.response {[self] resp in
            ProgressHUD.dismiss()
            
            guard resp.error == nil else{

                if resp.error!._code == NSURLErrorTimedOut {
                    ProgressHUD.show("Request Time Out", interaction: false)
                }else if resp.error!.isInvalidURLError {
                    ProgressHUD.show("Invalid URL", interaction: false)
                }else{
                    ProgressHUD.show(icon: .failed)
                }
                return
            }
            
            let dict = JSON(resp.data!)
            let state = dict["state"].intValue
            if state != 200 {
                return
            }
            let data = dict["data"]
            let decoder = JSONDecoder()
            let ota = try? decoder.decode(OtaModel.self, from: data.rawData())
            update(model: ota)
            
        }
    }
    
    private func update(model: OtaModel?) {
        if model == nil { return }
        infLab.text = String(format: "ID:%d BIN:%@", model!.customerID, model!.btName)
        versionData = model!.versionList
        tableView.reloadData()
    }
    
    @objc func changeServer() {
        local = local == 0 ? 1 : 0
        serverLab.text = getService()
        versionData = []
    }
    
    @objc func back() {
        dismiss(animated: false)
    }
    
    
    // MARK: - TableView
    func numberOfSections(in tableView: UITableView) -> Int {
        return versionData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let versionModel = versionData[section]
        return  section == openIdx ? versionModel.imgList.count : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: FileListCell = tableView.dequeueReusableCell(withIdentifier: "FileListCell") as! FileListCell
        let fileData = versionData[indexPath.section]
        let fileModel = fileData.imgList[indexPath.row]
        cell.nameLab.text = fileModel.name
        if fileModel.fileSize < (1024 * 1024) {
            cell.sizeLab.text = String(format:"%dKB", fileModel.fileSize/1024)
        }else{
            cell.sizeLab.text = String(format:"%dMB", (fileModel.fileSize/1024)/1024)
        }
        
        cell.downloadImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(downloadAlertWindow(tap:)))
        cell.downloadImageView.addGestureRecognizer(tap)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: 60))
        header.tag = section
        header.backgroundColor = .white
        
        let contentView = UIView(frame: CGRect(x: 15, y: 4, width: view.bounds.size.width-30, height: 52))
        contentView.backgroundColor = .systemBlue
        contentView.layer.cornerRadius = 8
        header.addSubview(contentView)
                
        let versionLab = UILabel()
        versionLab.frame = CGRect(x: 8, y: 0, width: 150, height: 31)
        versionLab.textColor = .white
        contentView.addSubview(versionLab)
        let versionModel = versionData[section]
        versionLab.text = "Version: " + versionModel.version
        
        let urlLab = UILabel()
        urlLab.frame = CGRect(x: 8, y: 27, width: contentView.frame.size.width, height: 21)
        urlLab.textColor = .white
        urlLab.font = UIFont.preferredFont(forTextStyle: .footnote)
        contentView.addSubview(urlLab)
        let fileModel: OtaFileModel = versionModel.imgList.first! as OtaFileModel

        if let url = URL(string: fileModel.url) {
            urlLab.text = url.deletingLastPathComponent().absoluteString
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(openVersion(tap:)))
        header.addGestureRecognizer(tap)
        
        return header
        
    }
    
    @objc func openVersion(tap: UITapGestureRecognizer) {
        openIdx = tap.view?.tag ?? 0
        tableView.reloadData()
    }
    
    @objc func downloadAlertWindow(tap: UITapGestureRecognizer) {

        let alert = UIAlertController(title: "Download", message: "Confirm the download", preferredStyle: .alert)
        let act1 = UIAlertAction(title: "Cancel", style: .default)
        let act2 = UIAlertAction(title: "Download", style: .default) { act in
            let contentView = tap.view?.superview
            let cell: UITableViewCell = contentView?.superview as! UITableViewCell
            let idxPath = self.tableView.indexPath(for: cell)
            let ota = self.versionData[idxPath!.section]
            let file = ota.imgList[idxPath!.row]
            self.download(url: file.url, fileName: file.name)
        }
        alert.addAction(act1)
        alert.addAction(act2)
        present(alert, animated: false)
    }
    
    private func download(url: String, fileName: String) {

        ProgressHUD.show("downloading", interaction: false)
        DispatchQueue.global().async {
            
            let destination: DownloadRequest.Destination = { _, _ in
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsURL.appendingPathComponent("fileName")
                return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
            }
            let purl: String = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            
            AF.download(purl, to: destination).responseData { resp in

                ProgressHUD.dismiss()

                guard resp.error == nil else{

                    if resp.error!._code == NSURLErrorTimedOut {
                        ProgressHUD.show("Request Time Out", interaction: false)
                    }else if resp.error!.isInvalidURLError {
                        ProgressHUD.show("Invalid URL", interaction: false)
                    }else{
                        ProgressHUD.show(icon: .failed)
                    }
                    return
                }

                if let data = resp.value {
                    self.downloadBlock!(fileName, data)
                    DispatchQueue.main.async {
                        self.dismiss(animated: false)
                    }
                }

            }

        }

    }
    
    deinit {
        print("😭😭😭😭😭😭 FileListViewController deinit")
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

