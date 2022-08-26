//
//  RestManager.swift
//  RestManager
//
//  Created by Gabriel Theodoropoulos.
//  Copyright © 2019 Appcoda. All rights reserved.
//

import Foundation

class RestManager {
    
    // MARK: - Properties
    
    //代表不同網路請求
    var requestHttpHeaders = RestEntity() //請求HTTP標頭
    
    var urlQueryParameters = RestEntity() //取得URL查詢參數
    
    var httpBodyParameters = RestEntity() //取得HTTP本文
    
    var httpBody: Data? //宣告HTTP本文（發送網路伺服器需要的任何資料）
    
    
    // MARK: - Public Methods
    
    func makeRequest(toURL url: URL,
                     withHttpMethod httpMethod: HttpMethod,
                     completion: @escaping (_ result: Results) -> Void) { //接受三個參數並向其發出網路請求的URL、httpMethod、包含請求結果的完成處理器（completion handler），escaping為會逃離的閉包函式
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in //在背景執行緒非同步進行以讓App維持響應狀態，qos設定執行緒優先順序，userInitiated為優先做此工作，降低其他工作的優先級別。weak self是確保在RestManeger的實例化因某些原因停止存活的話，任何類別屬性與方法的參照不會閃退
            let targetURL = self?.addURLQueryParameters(toURL: url) //加入URL查詢參數給指定的URL
            let httpBody = self?.getHttpBody() //取得HTTP本文
            
            guard let request = self?.prepareRequest(withURL: targetURL, httpBody: httpBody, httpMethod: httpMethod) else
            { //建立URL request物件並確認request不是nil
                completion(Results(withError: CustomError.failedToCreateRequest)) //若request為nil還是得回傳，但需完成處理器並傳送Results物件，所以須提供一個錯誤以解釋網路無法執行的原因
                return
            }
            
            //實際的網路請求會透過URLSession的實例來建立資料任務開始
            let sessionConfiguration = URLSessionConfiguration.default //初始化一個使用預設配置的對話（Session）物件
            let session = URLSession(configuration: sessionConfiguration)
            let task = session.dataTask(with: request) { (data, response, error) in //建立一個資料任務
                completion(Results(withData: data, //資料任務回傳data物件中伺服器傳送的實際資料以及
                                   response: Response(fromURLResponse: response), //作為URLResponse物件的回應以及
                                   error: error)) //任何潛在的錯誤
            }
            task.resume() //啟動資料任務
        }
    }
    
    
    
    func getData(fromURL url: URL, completion: @escaping (_ data: Data?) -> Void) { //從URL擷取資料
        DispatchQueue.global(qos: .userInitiated).async { //在背景執行緒非同步進行以讓App維持響應狀態
            let sessionConfiguration = URLSessionConfiguration.default //初始化URLSession物件
            let session = URLSession(configuration: sessionConfiguration)
            let task = session.dataTask(with: url, completionHandler: { (data, response, error) in //使用資料任務從已有的URL擷取資料
                
                guard let data = data else { completion(nil); return } //確認資料是否已被擷取，若沒有則回傳nil
                completion(data) //呼叫完成處理器傳送實際資料
            })
            task.resume() //啟動資料擷取
        }
    }
    
    
    
    // MARK: - Private Methods
    
    private func addURLQueryParameters(toURL url: URL) -> URL { //添加任何的URL查詢參數到原始URL上，若無參數則回傳原始URL
        if urlQueryParameters.totalItems() > 0 { //確認是否有URL查詢參數
            guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url } //取得原始URL物件
            var queryItems = [URLQueryItem]() //queryItems陣列裡每個物件代表一個URL查詢項目
            for (key, value) in urlQueryParameters.allValues() { //迭代URL查詢參數裡的所有數值
                let item = URLQueryItem(name: key, value: value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)) //對每個找到的查詢參數建立新的URLQueryItem並進行百分比符號編碼
                
                queryItems.append(item) //將上面的參數放到queryItems陣列裡
            }
            
            urlComponents.queryItems = queryItems //將前面建立好的查詢項目陣列指派到urlComponents裡的查詢項目陣列
            
            guard let updatedURL = urlComponents.url else { return url } //取得包含查詢參數的完整URL（urlComponents）
            return updatedURL //回傳此完整URL
        }
        
        return url //若沒有URL查詢參數，則回傳原始URL
    }
    
    
    
    private func getHttpBody() -> Data? { //取得HTTP本文
        guard let contentType = requestHttpHeaders.value(forKey: "Content-Type") else { return nil } //確認是否已透過requestHttpHeaders的屬性設定Content-Type請求HTTP headers，若沒有就代表網路請求沒有包含本文，所以回傳nil
        
        //檢查Content-Type數值的例子，確認是否已設定任何內容的型別
        if contentType.contains("application/json") { //contentType為JSON物件（Data物件）的例子
            return try? JSONSerialization.data(withJSONObject: httpBodyParameters.allValues(), options: [.prettyPrinted, .sortedKeys]) //（httpBodyParameters物件if裡的數值必須被轉換為JSON）回傳（prettyPrinted：帶有空格的JSON，更具可讀性，若未設置則會生成最緊湊的JSON）http本文中JSON物件的所有鍵值對
        } else if contentType.contains("application/x-www-form-urlencoded") { //contentType為application/x-www-form-urlencoded的例子
            let bodyString = httpBodyParameters.allValues().map { "\($0)=\(String(describing: $1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)))" }.joined(separator: "&") //建置一個查詢字串並以百分比符號編碼這個數值
            return bodyString.data(using: .utf8)
        } else {
            return httpBody //其他例子就直接回傳httpBody
        }
    }
    
    
    //透過參數傳送URL（包括查詢參數）、HTTP Body、HTTP Method，使用HTTP Method製作網路請求，最後回纏URLRequest
    private func prepareRequest(withURL url: URL?, httpBody: Data?, httpMethod: HttpMethod) -> URLRequest? { //準備URL請求並初始化及配置一個URLRequest物件
        guard let url = url else { return nil } //確認傳入的URL是不是nil
        var request = URLRequest(url: url) //用傳入的URL初始化URLRequest物件
        request.httpMethod = httpMethod.rawValue //指派httpMethod（必須以字串數值請求，所以用原始數值RawValue請求）
        
        for (header, value) in requestHttpHeaders.allValues() { //指派http headers到request物件
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        request.httpBody = httpBody //指派httpBody到對應的request物件
        return request
    }
}


// MARK: - RestManager Custom Types

extension RestManager { //清楚指出這些自定型別的用途
    enum HttpMethod: String { //各式各樣的HTTP方法
        case get
        case post
        case put
        case patch
        case delete
    }

    
    
    struct RestEntity { //用具有字串數值的字典管理HTTP headers & URL & HTTP body
        private var values: [String: String] = [:] //建立HTTP的字典
        
        mutating func add(value: String, forKey key: String) { //為了修改struct裡key對應的值
            values[key] = value
        }
        
        func value(forKey key: String) -> String? { //取得key對應的值（也就是HTTP內容對應的值）
            return values[key]
        }
        
        func allValues() -> [String: String] { //取得字典裡的所有鍵質對（Key-Value Pairs）
            return values
        }
        
        func totalItems() -> Int { //取得字典裡鍵質對的數目
            return values.count
        }
    }
    
    
    
    struct Response {
        var response: URLResponse? //保留實際的回應物件（URLResponse），此物件不包含伺服器回傳的實際資料
        var httpStatusCode: Int = 0 //狀態碼（代表請求的結果）
        var headers = RestEntity() //結構的實例
        
        init(fromURLResponse response: URLResponse?) { //初始化Response物件
            guard let response = response else { return }
            self.response = response
            httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0 //為了取得HTTP狀態碼需要將回應參數從URLResponse轉換為HTTPURLResponse物件再存取statusCode
            
            if let headerFields = (response as? HTTPURLResponse)?.allHeaderFields { //保留回應中的所有HTTP headers
                for (key, value) in headerFields {
                    headers.add(value: "\(value)", forKey: "\(key)")
                }
            }
        }
    }
    
    
    
    struct Results { //呈現網路請求結果
        var data: Data? //請求成功則獲得伺服器的實際資料
        var response: Response? //回應裡的其他資料
        var error: Error? //任何潛在錯誤
        
        init(withData data: Data?, response: Response?, error: Error?) { //為三個屬性接受參數
            self.data = data
            self.response = response
            self.error = error
        }
        
        init(withError error: Error) { //只接受錯誤物件為參數
            self.error = error
        }
    }

    
    
    enum CustomError: Error { //在URL請求物件無法被建立時，需回為傳此自訂的錯誤給RestManager的呼叫器來指出錯誤
        case failedToCreateRequest
    }
}


// MARK: - Custom Error Description
extension RestManager.CustomError: LocalizedError { //提出自訂錯誤
    public var localizedDescription: String { //建立“URL請求無間無法被建立”的自訂錯誤
        switch self {
        case .failedToCreateRequest: return NSLocalizedString("Unable to create the URLRequest object", comment: "")
        }
    }
}
