//
//  YProgressView.swift
//  YDownloadManager
//
//  Created by shusy on 2017/12/26.
//  Copyright © 2017年 杭州爱卿科技. All rights reserved.
//

import UIKit

class YProgressView: UIView {
    
    var progress:Float = 0 {
        didSet{
            self.setNeedsDisplay()
        }
    }
    override func draw(_ rect: CGRect) {
        UIColor.red.set()
//        print("progress===\(self.progress)")
        UIRectFill(CGRect(x: 0, y: 0, width: CGFloat(self.progress)*rect.size.width, height: 4))
    }
}
