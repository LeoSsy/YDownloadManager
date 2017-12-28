//
//  YDownloadManager.swift
//  YDownloadManager
//
//  Created by shusy on 2017/12/25.
//  Copyright © 2017年 杭州爱卿科技. All rights reserved.
//

import UIKit

/// 下载状态
public enum YDownloadState : Int {
    case normal                 //默认状态
    case willResume           //即将下载
    case resume                 // 下载中
    case suspend                // 暂停中
    case finished                //下载完成
}

class YDownloadManager: NSObject,URLSessionDataDelegate {
    var maxDownloadingCount = 0  //最大下载的文件数
    {
        didSet{
            self.queue.maxConcurrentOperationCount = maxDownloadingCount
        }
    }
    var batching:Bool = false           //是否正在批量处理
    fileprivate lazy var session:URLSession = { //创建 session 对象
        let cfg = URLSessionConfiguration.default
        let session = URLSession(configuration: cfg, delegate: self, delegateQueue: self.queue)
        return session
    }()
    
   fileprivate  lazy var queue:OperationQueue = { //创建所有的操作队列
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
   fileprivate lazy var downloadTasks:Array<YDownloadInfo> = { //创建所有文件下载数组
        let downloadTasks = Array<YDownloadInfo>()
        return downloadTasks;
    }()
    
    static var _managers = Dictionary<String,YDownloadManager>() //保存全局管理对象
    /// 初始化方法
    override init() {
        _totalFileSizesFile = (YDownloadRootDir + "/" + "YDownloadFileSizes.plist".md5).addCachePath()
        _totalFileSizes = NSMutableDictionary(contentsOfFile: _totalFileSizesFile)
        if _totalFileSizes == nil {
            _totalFileSizes = NSMutableDictionary()
        }
        super.init()
    }
    
   public class func defaultManager()->YDownloadManager { //获取默认的下载管理者
        return defaultManagerWithIdentfier(identifierName: downdloadManagerDefaultIdentifier)
    }
    
   fileprivate class func defaultManagerWithIdentfier(identifierName:String?) -> YDownloadManager {
        guard let identifierName = identifierName  else {
            return  manager()
        }
        var mgr:YDownloadManager!
        if  _managers[identifierName] == nil {
            mgr = manager()
            _managers[identifierName] = mgr
        }
        return _managers[identifierName]!
    }
    
   fileprivate class func manager()->YDownloadManager {
        return YDownloadManager()
    }

    /// 公共方法
    ///
    /// - Parameters:
    ///   - url: 文件地址
    ///   - toDestinationPath: 文件绝对地址
    ///   - progress: 下载进度改变的回调
    ///   - state: 下载状态改变的回调
    func download(url:String?,toDestinationPath:String?,progress:downloadProgressBlock?,state:downloadStateBlock?)->YDownloadInfo?{
        if url == nil { return nil }
        //获取下载信息
        if let downloadinfo = self.downloadInfo(forUrl: url) {
            //设置回调
            downloadinfo.downloadProgressBlock = progress
            downloadinfo.downloadStateBlock = state
            //设置文件路径
            if toDestinationPath != nil {
                downloadinfo.fileName = toDestinationPath!.components(separatedBy: "/").last
                downloadinfo.file = toDestinationPath
            }
            //检查下载状态
            if downloadinfo.state == .finished {
                //通知状态当前下载对象 状态改变
                downloadinfo.notifyStateChange()
                return downloadinfo
            }else if (downloadinfo.state == .resume) {
                return downloadinfo
            }
            //创建任务
            downloadinfo.setupTask(session: self.session)
            //开启下载任务
            downloadinfo.resume()
        }
        return nil
    }
    
    func download(url:String)->YDownloadInfo? {
      return  download(url: url, toDestinationPath: nil, progress: nil, state: nil)
    }
    
    func download(url:String?,pregress:downloadProgressBlock?)->YDownloadInfo? {
       return  download(url: url, toDestinationPath: nil, progress: pregress, state: nil)
    }
    
    func download(url:String?,progress:downloadProgressBlock?,state:downloadStateBlock?)->YDownloadInfo? {
       return download(url: url, toDestinationPath: nil, progress: progress, state: state)
    }

}


// MARK: - 文件相关操作
extension YDownloadManager{
    
    /// 让当前下载队列中等待下载的的第一个任务开始下载
    func resumeFirstTask()  {
        if !self.batching {return}
        let info = self.downloadTasks.filter { (info) -> Bool in
            if info.state == .willResume {
                return true
            }
            return false
        }.first
        self.resume(url: info?.url)
    }
    
    /// 取消所有的下载任务
    func cancleAll(){
        for info in downloadTasks {
            self.cancle(url: info.url)
        }
    }

    /// 取消所有下载任务
    class func cancleAll(){
        for mgr in _managers {
            mgr.value.cancleAll()
        }
    }
    
    /// 暂停所有任务
    func suspendAll(){
        self.batching = true
        for info in downloadTasks {
            self.suspend(url:info.url)
        }
        self.batching = false
    }
    
    /// 暂停所有任务
    class func suspendAll(){
        for mgr in _managers {
            mgr.value.suspendAll()
        }
    }
    
    /// 开始所有任务
    func resumeAll(){
        for info in downloadTasks {
            self.resume(url:info.url)
        }
    }
    
    /// 开始所有任务
    class func resumeAll(){
        for mgr in _managers {
            mgr.value.resumeAll()
        }
    }

}

// MARK: - 下载任务相关操作
extension YDownloadManager {
    
    /// 取消一个任务
    ///
    /// - Parameter url: url
    func cancle(url:String?){
        if url == nil {return}
        //取消当前的任务
        self.downloadInfo(forUrl: url)?.cancle()
    }

    /// 暂停一个任务
    ///
    /// - Parameter url: url
    func suspend(url:String?){
        if url == nil {return}
        self.downloadInfo(forUrl: url)?.suspend()
        self.resumeFirstTask()
    }
    
    /// 恢复一个任务
    ///
    /// - Parameter url: URL
    func resume(url:String?){
        if url == nil {return}
        //获取下载信息
        let info = self.downloadInfo(forUrl: url)
        //获取当前的下载队列中正在下载的任务
        let resumeArray = self.downloadTasks.filter { (info) -> Bool in
            if info.state == .resume { return true }
            return false
        }
        if self.maxDownloadingCount != 0 && resumeArray.count == self.maxDownloadingCount {
            info?.willResume()
        }else{
            info?.resume()
        }
    }
}

// MARK: - 数据处理逻辑相关方法
extension YDownloadManager {
    func downloadInfo(forUrl:String?)->YDownloadInfo? {
        if forUrl == nil {return nil}
        var downloadInfo:YDownloadInfo?
        for info in downloadTasks {
            if info.url! == forUrl! {
                downloadInfo = info
            }
        }
        if downloadInfo == nil {
            downloadInfo = YDownloadInfo()
            downloadInfo?.url = forUrl
            downloadTasks.append(downloadInfo!)
        }
        return downloadInfo
    }
}


// MARK: - session代理方法
extension YDownloadManager {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        //获得下载信息
        let downloadInfo = self.downloadInfo(forUrl: dataTask.taskDescription)
        //处理响应
        downloadInfo?.didReceiveResponse(response: response as! HTTPURLResponse)
        //继续处理数据
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        //获得下载信息
        let info = self.downloadInfo(forUrl: dataTask.taskDescription)
        //处理数据
        info?.didReceiveData(data: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        //获得下载信息
        let info = self.downloadInfo(forUrl: task.taskDescription)
        //处理数据
        info?.didFinishedError(error: error)
        //开始等待下载的任务
        info?.willResume()
    }
}
