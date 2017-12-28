//
//  ViewController.swift
//  YDownloadManager
//
//  Created by shusy on 2017/12/25.
//  Copyright © 2017年 杭州爱卿科技. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {

    var urls:Array<String>!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        urls = Array<String>()
        for index in 1...10 {
            let url = String(format: "http://120.25.226.186:32812/resources/videos/minion_%02d.mp4", index)
            print(url)
            urls.append(url)
        }
        
        YDownloadManager.defaultManager().maxDownloadingCount = 1
        
    }

    @IBAction func suspendAll(_ sender: Any) {
        YDownloadManager.defaultManager().suspendAll()
    }
    
    @IBAction func resumeAll(_ sender: Any) {
        YDownloadManager.defaultManager().resumeAll()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return urls.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "download") as! DownloadCell
        cell.url = urls[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let url = urls[indexPath.row]
        print("url===\(url)")
    }
    
    
}

