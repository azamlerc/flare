//
//  APIManager.swift
//  Facets Dashboard
//
//  Created by Andrew Zamler-Carhart on 29/08/2014.
//  Copyright (c) 2014 Cisco. All rights reserved.
//

import Foundation

public class APIManager: NSObject {
    
    public var server = "http://localhost:80"
    public var debugHttp = true

    public enum HTTPMethod: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
    }
    
    // takes a uri, params, method and message
    // handler called with json and other info
    public func sendRequestDetailed(uri: String,
        params: JSONDictionary?,
        method: HTTPMethod,
        message: JSONDictionary?,
        handler: @escaping (AnyObject, NSURLRequest, URLResponse?, Double) -> ())
    {
        let startTime = NSDate()
        let url = urlWithParams(uri: uri, params:params)
        let request = NSMutableURLRequest(url:url as URL)
        request.httpMethod = method.rawValue
        
        if debugHttp { NSLog("url: \(request.httpMethod) \(url)") }
        
        if (message != nil) {
            let messageData = try? JSONSerialization.data(withJSONObject: message!, options:[])
            let messageString = NSString(data: messageData!, encoding: String.Encoding.utf8.rawValue)
            
            request.httpBody = messageData
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if debugHttp { NSLog("message: \(messageString!)") }
        }
        
        NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: OperationQueue.main,
                                                completionHandler: {(response: URLResponse?, data: Data?, error: Error?) -> () in
                if error == nil {
                    let duration = 0 - startTime.timeIntervalSinceNow
                    if let json: AnyObject = try! JSONSerialization.jsonObject(with: data!, options: []) as AnyObject?  {
                        handler(json, request, response, duration)
                    } else {
                        let result = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)!
                        handler(["result":result] as NSDictionary, request, response, duration)
                    }
                } else {
                    NSLog("Error: \(error!.localizedDescription)")
                }
        })
    }
    
    // takes a uri, params, method and message
    // handler called with json only
    public func sendRequest(uri: String,
        params: JSONDictionary?,
        method: HTTPMethod,
        message: JSONDictionary?,
        handler: @escaping (AnyObject) -> ())
    {
        sendRequestDetailed(uri: uri, params:params, method:method, message:message) {(json, request, response, duration)->() in handler(json) }
    }
    
    // GET request, takes a uri and params
    // handler called with json and other info
    public func sendRequestDetailed(uri: String,
        params: JSONDictionary?,
        handler: @escaping (AnyObject, NSURLRequest, URLResponse?, Double) -> ())
    {
        sendRequestDetailed(uri: uri, params:params, method:.GET, message:nil, handler:handler)
    }
    
    // GET request, takes a uri and params
    // handler called with json only
    public func sendRequest(uri: String, params: JSONDictionary?, handler: @escaping (AnyObject) -> ()) {
        sendRequest(uri: uri, params:params, method:.GET, message:nil, handler:handler)
    }
    
    // GET request, takes a uri
    // handler called with json and other info
    public func sendRequestDetailed(uri: String, handler: @escaping (Any, NSURLRequest, URLResponse?, Double) -> ()) {
        sendRequestDetailed(uri: uri, params:nil, handler:handler)
    }
    
    // GET request, takes a uri
    // handler called with json only
    public func sendRequest(uri: String, handler: @escaping (AnyObject) -> ()) {
        sendRequest(uri: uri, params:nil, handler:handler)
    }
    
    // returns a fully-qualified URL with the given uri and parameters
    public func urlWithParams(uri: String, params: JSONDictionary?) -> NSURL {
        var urlString = uri.contains("://") ? uri : server + "/" + uri
        if params != nil && params!.count > 0 {
            urlString += "?" + paramString(params: params!)
        }
        let url: NSURL? = NSURL(string:urlString)
        return url!
    }
    
    // formats the parameters for a URL
    public func paramString(params: JSONDictionary) -> String {
        let keyValues = NSMutableArray()
        for (key, value) in params { keyValues.add("\(key)=\(value)") }
        return keyValues.componentsJoined(by: "&")
    }
    
    public func jsonDict(json: AnyObject?) -> JSONDictionary {
        if let dict = json as? JSONDictionary {
            return dict
        }
        return [:]
    }
    
    // this handler can be used to print out all info from an API call
    public var printInfo = {(json: JSONDictionary, request: NSURLRequest, response: URLResponse?, duration: Double) -> () in
        print("url: \(request.httpMethod ?? "") \(request.url!)")
        if response != nil { print("response: \((response! as! HTTPURLResponse).statusCode)") }
        print("json: \(json)")
        print("duration: \(duration)")
    }
    
    // this handler can be used to print out the json from an API call
    public var printJson = {(json: JSONDictionary) -> () in
        print("json: \(json)")
    }
}
