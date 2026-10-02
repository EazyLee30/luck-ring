//
//  FileListCell.swift
//  ota2.0
//
//  Created by coolwear on 2022/8/12.
//

import UIKit

class FileListCell: UITableViewCell {
    
    let nameLab = UILabel()
    let sizeLab = UILabel()
    let downloadImageView = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        
        nameLab.frame = CGRect(x: 24, y: 4, width: 300, height: 30)
        contentView.addSubview(nameLab)
        
        sizeLab.frame = CGRect(x: nameLab.frame.origin.x, y: nameLab.frame.origin.y + nameLab.frame.height, width: 300, height: 14)
        sizeLab.textColor = .lightGray
        sizeLab.font = UIFont.preferredFont(forTextStyle: .footnote)
        contentView.addSubview(sizeLab)
        
        downloadImageView.image = UIImage(named: "下载")
        downloadImageView.frame = CGRect(x: UIScreen.main.bounds.size.width - 40, y: 16, width: 16, height: 24)
        contentView.addSubview(downloadImageView)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
