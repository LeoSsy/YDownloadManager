//
//  YDownloadInfo.swift
//  YDownloadManager
//
//  Created by shusy on 2017/12/25.
//  Copyright © 2017年 杭州爱卿科技. All rights reserved.
//

import UIKit

/** 存放所有的文件大小 */
var _totalFileSizes:NSMutableDictionary!
/** 存放所有的文件大小的文件路径 */
var _totalFileSizesFile:String!
/** 回调方法 */
typealias downloadProgressBlock = (_ downloadBytes:NSInteger,_ totalBytes:NSInteger)->Void
typealias downloadStateBlock = (_ state:YDownloadState,_ file:String?, _ error:Error?)->Void

class YDownloadInfo: NSObject {
    /// 进度改变的block
    var downloadProgressBlock:downloadProgressBlock?
    /// 下载状态改变的block
    var downloadStateBlock:downloadStateBlock?
    var _file:String? //文件路径
    /// 文件的本地路径
    var file:String? {
        get{
            if _file != nil { return _file }
            _file = (YDownloadRootDir + "/" + self.fileName!).addCachePath()
            //获取目录名称
            var url = URL(string: _file!)
            if (!FileManager.default.fileExists(atPath: url!.absoluteString)) {
                url?.deleteLastPathComponent()
                //获取目录名称
                let dir = url!.lastPathComponent
                //创建目录
                try? FileManager.default.createDirectory(atPath: dir.addCachePath(), withIntermediateDirectories: true, attributes: nil)
            }
            return _file!
        }
        set{
            _file = newValue
        }
    }
    /// 文件url地址
    var url:String?
    /// 文件名称
    var _fileName:String?
    var fileName:String? {
        set{
            _fileName = newValue
        }
        get{
            guard _fileName == nil else {return _fileName }
            let pathExtention = URL(string: self.url!)?.pathExtension
            if ((pathExtention?.count) != nil) {
                _fileName = self.url!.md5 + "." + pathExtention!
            }else{
                _fileName = self.url?.md5
            }
            return _fileName
        }

    }
    /// 文件当前的状态
    var state:YDownloadState = .normal {
        didSet{
            //设置新的状态
            if self.totalBytes != 0 && self.downloadBytes == self.totalBytes {
                state = .finished
            }
            if self.error != nil { state = .normal}
            //发送状态改变的通知
            notifyStateChange()
        }
    }
    /// 已经写入的字节数
    var  bytesWritten:NSInteger = 0
    /// 已经下载的字节数
    var downloadBytes:NSInteger {
        get{
            return NSInteger(self.file!.fileSize())
        }
        set{}
    }
    /// 文件总的字节数
    var _totalBytes:NSInteger = 0
    var  totalBytes:NSInteger{
        set{_totalBytes = newValue}
        get{
            if _totalBytes != 0 { return _totalBytes }
            if _totalFileSizes[self.url!] != nil {
                _totalBytes = _totalFileSizes[self.url!] as! NSInteger
            }else{
                _totalBytes = 0
            }
            return _totalBytes
        }
    }
    /// 错误信息
    var error:Error?
    /// 下载任务
    var dataTask:URLSessionDataTask?
    /// 文件句柄
    var fileHandle:FileHandle?
    /// 进度值改变的通知
    func notifyProgreshChange(){
        DispatchQueue.main.async {
            self.downloadProgressBlock != nil ? self.downloadProgressBlock!(self.downloadBytes,self.totalBytes) : nil
        }
    }
    
    /// 下载状态改变的通知
    func notifyStateChange(){
        DispatchQueue.main.async {
            self.downloadStateBlock != nil ? self.downloadStateBlock!(self.state,self.file,self.error) : nil
        }
    }
    
    /// 取消任务
    func cancle() {
        if self.state == .finished || self.state == .normal { return }
        self.dataTask?.cancel()
        self.state = .normal
    }

    /// 恢复下载
    func resume(){
        if self.state == .finished || self.state == .resume { return }
        self.dataTask?.resume()
        self.state = .resume
    }
    
    /// 暂停任务
    func suspend(){
        if self.state == .suspend || self.state == .finished {return}
        self.dataTask?.suspend()
        self.state = .normal
    }
    
    /// 等待下载
    func willResume(){
        if self.state == .finished || self.state == .willResume {return}
        self.state = .willResume
    }

    /// 初始化任务
    ///
    /// - Parameter session: session 对象
    func setupTask(session:URLSession){
        if dataTask != nil { return }
        if let url = self.url {
            let request = NSMutableURLRequest(url: URL(string: url)!)
            let range = "bytes=\(self.downloadBytes)-"
            request.setValue(range, forHTTPHeaderField: "Range")
            dataTask = session.dataTask(with: request as URLRequest)
            dataTask?.taskDescription = url
        }
    }
    
    /// 处理响应数据获取当前下载文件的总的大小信息
    ///
    /// - Parameter response: http响应
    func didReceiveResponse(response:HTTPURLResponse) {
        //获取文件总长度
        if totalBytes == 0 {
            totalBytes = (response.allHeaderFields["Content-Length"] as! NSString).integerValue + self.downloadBytes
            //存储文件总长度
            if let url = self.url {
                _totalFileSizes[url] = totalBytes
                _totalFileSizes.write(toFile: _totalFileSizesFile, atomically: true)
            }
        }
        //创建文件句柄对象
         creatFileHandle()
        //清空错误
        self.error = nil
    }
    
    /// 创建文件句柄对象
    func creatFileHandle(){
        let exist=FileManager.default.fileExists(atPath: self.file!)
        if !exist{
            FileManager.default.createFile(atPath: self.file!, contents: nil, attributes: nil)
        }
        if self.fileHandle == nil {
            self.fileHandle = FileHandle(forWritingAtPath: self.file!)
        }
    }

    /// 获取到数据
    ///
    /// - Parameter data: 服务器响应数据
    func didReceiveData(data:Data){
        //判断系统的可用空间是否足够
        if !availableSystemFreeSize(data: data) {return}
        //开始写入数据
        // 此处可能会拿到文件句柄为空 所有重新创建下 创建文件句柄对象
        creatFileHandle()
        //每次写入数据之前先讲文件指针移动到文件的末尾
        self.fileHandle?.seekToEndOfFile()
        self.fileHandle?.write(data)
        self.bytesWritten = data.count
        //发送进度值改变的通知
        notifyProgreshChange()
    }
    
    /// 下载完成
    ///
    /// - Parameter error: 错误信息
    func didFinishedError(error:Error?){
        //关闭流
        self.fileHandle?.closeFile()
        self.bytesWritten = 0
        self.dataTask = nil
        self.fileHandle = nil
        //设置错误信息
        self.error = error ?? self.error
        //设置状态
        if state == .finished || error != nil {
            self.state = error != nil ? .normal : .finished
        }
    }
    
    /// 检查系统的空间是否充足 当可用空间不足100M的时候提示
    func availableSystemFreeSize(data:Data?)->Bool {
        let freeSize = String.systemfreeSize()
        //如果存在data值 就计算data的值
        var hint = "可用存储空间不足100M"
        if data != nil {
            hint = "可用存储空间不足\(data!.count/1024/1024)M"
        }
        if freeSize < (data?.count ?? 1024*1024*50 ){ //如果可用空间小于50M
            let alert:UIAlertController=UIAlertController.init(title: "提示", message: hint, preferredStyle: UIAlertControllerStyle.alert)
            let confirmAction=UIAlertAction.init(title: "确定", style: UIAlertActionStyle.default, handler: nil)
            alert.addAction(confirmAction)
            let root=UIApplication.shared.keyWindow?.rootViewController
            root?.present(alert, animated: true, completion: nil)
            return false
        }
        return true
    }
    
}
