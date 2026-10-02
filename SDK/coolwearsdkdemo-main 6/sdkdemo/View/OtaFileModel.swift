//
//  OtaFileModel.swift
//  ota2.0
//
//  Created by coolwear on 2022/8/11.
//

import UIKit
import SwiftyJSON

struct OtaModel: Codable {
    var btName: String
    var customerID: Int
    var versionList: [OtaVersionModel]
}

struct OtaVersionModel: Codable{
    var version: String
    var imgList: [OtaFileModel]
}

struct OtaFileModel: Codable {
    var url: String
    var name: String
    var fileSize: Int
}
