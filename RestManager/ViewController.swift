//
//  ViewController.swift
//  RestManager
//
//  Created by Gabriel Theodoropoulos.
//  Copyright © 2019 Appcoda. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    let rest = RestManager()
    override func viewDidLoad() {
        super.viewDidLoad()
        getUsersList() //擷取使用者列表
        //getNonExistingUser() //確認HTTP狀態碼
        //createUser() //建立新使用者
        //getSingleUser() //擷取一個使用者的頭貼圖
    }
    func getUsersList() { //擷取使用者列表
        guard let url = URL(string: "https://reqres.in/api/users") else { return } //從此URL擷取使用者列表
        
        rest.urlQueryParameters.add(value: "2", forKey: "page") //提供URL查詢參數指出想擷取的資料頁數
        
        rest.makeRequest(toURL: url, withHttpMethod: .get) { (results) in //指定URL及HTTP方法
            if let data = results.data { //使用完成處理器中的results物件
                let decoder = JSONDecoder() //results裡的data是Optional，所以使用前需先解包，初始化JSONDecoder
                decoder.keyDecodingStrategy = .convertFromSnakeCase //用KeyDecodingStrategy的convertFromSnakeCase方式解碼資料
                guard let userData = try? decoder.decode(UserData.self, from: data) else { return }
                print(userData.description)
            }
            
            print("\n\nResponse HTTP Headers:\n") //印出http headers

            if let response = results.response { //找到http headers
                for (key, value) in response.headers.allValues() {
                    print(key, value)
                }
            }
        }
    }
    
    func getNonExistingUser() { //確認HTTP狀態碼
        guard let url = URL(string: "https://reqres.in/api/users/100") else { return } //製作至此URL的請求

        rest.makeRequest(toURL: url, withHttpMethod: .get) { (results) in
            if let response = results.response {
                if response.httpStatusCode != 200 {
                    print("\nRequest failed with HTTP status code", response.httpStatusCode, "\n")
                }
            }
        }
    }
    
    func createUser() { //建立新的使用者
        guard let url = URL(string: "https://reqres.in/api/users") else { return }

        rest.requestHttpHeaders.add(value: "application/json", forKey: "Content-Type") //指定HTTP Headers
        rest.httpBodyParameters.add(value: "John", forKey: "name") //透過httpBodyParameters指定HTTP本文
        rest.httpBodyParameters.add(value: "Developer", forKey: "job")

        rest.makeRequest(toURL: url, withHttpMethod: .post) { (results) in //製作POST請求
            guard let response = results.response else { return }
            if response.httpStatusCode == 201 { //只有在HTTP狀態碼為201時才會解碼資料
                guard let data = results.data else { return }
                let decoder = JSONDecoder()
                guard let jobUser = try? decoder.decode(JobUser.self, from: data) else { return }
                print(jobUser.description)
            }
        }
    }
    
    func getSingleUser() { //擷取一個使用者的頭貼圖
        guard let url = URL(string: "https://reqres.in/api/users/1") else { return }

        rest.makeRequest(toURL: url, withHttpMethod: .get) { (results) in //根據指定URL中看到的ID數值來擷取單一使用者
            if let data = results.data {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                guard let singleUserData = try? decoder.decode(SingleUserData.self, from: data),
                    let user = singleUserData.data,
                    let avatar = user.avatar,
                    let url = URL(string: avatar) else { return }

                self.rest.getData(fromURL: url, completion: { (avatarData) in
                    guard let avatarData = avatarData else { return }
                    let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0] //儲存到Caches資料夾裡
                    let saveURL = cachesDirectory.appendingPathComponent("avatar.jpg")
                    try? avatarData.write(to: saveURL)
                    print("\nSaved Avatar URL:\n\(saveURL)\n")
                })

            }
        }
    }
}
