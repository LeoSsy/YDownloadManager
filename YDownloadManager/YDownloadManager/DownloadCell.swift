//
//  DownloadCell.swift
//  YDownloadManager
//
//  Created by shusy on 2017/12/26.
//  Copyright © 2017年 杭州爱卿科技. All rights reserved.
//

import UIKit

class DownloadCell: UITableViewCell {
    
    @IBOutlet weak var progressView: YProgressView!
    @IBOutlet weak var downBtn: UIButton!
    var downloadInfo:YDownloadInfo?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        progressView.isHidden = true
    }
    
    var url:String? {
        didSet{
            guard let newurl = url else {return}
            guard let info = YDownloadManager.defaultManager().downloadInfo(forUrl: newurl) else {return}
            self.textLabel?.text = newurl.components(separatedBy: "/").last
            downloadInfo = info
            if info.state == .finished {
                progressView.isHidden = true
                downBtn.isHidden = false
                self.downBtn.setImage(#imageLiteral(resourceName: "check"), for: UIControlState.normal)
            }else if(info.state == .willResume){
                progressView.isHidden = false
                downBtn.isHidden = false
                self.downBtn.setImage(#imageLiteral(resourceName: "clock"), for: UIControlState.normal)
            }else if(info.state == .resume){
                progressView.isHidden = false
                downBtn.isHidden = false
                if info.totalBytes != 0 {
                    self.progressView.progress = 1.0*Float(info.downloadBytes)/Float(info.totalBytes)
                }else{
                    self.progressView.progress = 0.0
                }
                self.downBtn.setImage(#imageLiteral(resourceName: "pause"), for: UIControlState.normal)
            }else if (info.state == .suspend){
                self.downBtn.setImage(#imageLiteral(resourceName: "pause"), for: UIControlState.normal)
                progressView.isHidden = true
                downBtn.isHidden = false
                self.downBtn.setImage(#imageLiteral(resourceName: "download"), for: UIControlState.normal)
            }else{
                progressView.isHidden = true
                downBtn.isHidden = false
                self.downBtn.setImage(#imageLiteral(resourceName: "download"), for: UIControlState.normal)
            }
            
        }
    }

    @IBAction func downloadBtnClick(_ sender: Any) {
        //判断系统的可用空间是否足够
        if !(downloadInfo?.availableSystemFreeSize(data: nil))! {return}
          guard let url = self.url else { return }
          if let info = YDownloadManager.defaultManager().downloadInfo(forUrl:url) {
                if info.state == .resume || info.state == .willResume {
                    YDownloadManager.defaultManager().suspend(url: info.url)
                }else{
                   _ =  YDownloadManager.defaultManager().download(url: url, progress: { (downloadBytes, totalBytes) in
                    DispatchQueue.main.async(execute: {
                        self.url = url
                    })
                    }, state: { (state, file, error) in
                        DispatchQueue.main.async(execute: {
                            self.url = url
                        })
                   })
                }
            }
        }
}
