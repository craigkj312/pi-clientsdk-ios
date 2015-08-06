/**
*   PresenceInsightsSDK
*   PIAdapter.swift
*
*   Performs all communication to the PI Rest API.
*
*   Created by Kyle Craig on 7/16/15.
*   Copyright (c) 2015 IBM Corporation. All rights reserved.
**/

import UIKit

// TODO: Handle error states with throw once 2.0 is released.

// MARK: - PIAdapter object
public class PIAdapter: NSObject {
    
    private let TAG = "[MILPresenceInsightsSDK] "
    
    private let _configSegment = "/pi-config/v1/"
    private let _beaconSegment = "/conn-beacon/v1/"
    private let _analyticsSegment = "/analytics/v1/"
    private let _httpContentTypeHeader = "Content-Type"
    private let _httpAuthorizationHeader = "Authorization"
    private let _contentTypeJSON = "application/json"
    private let GET = "GET"
    private let POST = "POST"
    private let PUT = "PUT"
    
    private var _baseURL: String!
    private var _configURL: String!
    private var _tenantCode: String!
    private var _orgCode: String!
    private var _authorization: String!
    
    private var _debug: Bool = false
    
    /**
    Default object initializer.
    
    :param: tenant   PI Tenant Code
    :param: org      PI Org Code
    :param: baseURL  The base URL of your PI service.
    :param: username PI Username
    :param: password PI Password
    
    :returns: An initialized PIAdapter.
    */
    public init(tenant:String, org:String, baseURL:String, username:String, password:String) {
        
        _tenantCode = tenant
        _orgCode = org
        _baseURL = baseURL
        _configURL = _baseURL + _configSegment + "tenants/" + _tenantCode + "/orgs/" + _orgCode
        
        let authorizationString = username + ":" + password
        _authorization = "Basic " + (authorizationString.dataUsingEncoding(NSASCIIStringEncoding)?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding76CharacterLineLength))!
        
        println(TAG + "Adapter Initialized with URL: \(_configURL)")
        
    }
    
    /**
    Convenience initializer which sets a default baseURL.
    
    :param: tenant   PI Tenant Code
    :param: org      PI Org Code
    :param: username PI Username
    :param: password PI Password
    
    :returns: An initialized PIAdapter.
    */
    public convenience init(tenant:String, org:String, username:String, password:String) {
        let defaultURL = "https://presenceinsights.ng.bluemix.net"
        self.init(tenant: tenant, org: org, baseURL: defaultURL, username: username, password: password)
    }
    
    /**
    Public function to enable logging for debug purposes.
    */
    public func enableLogging() {
        _debug = true
    }
}

// MARK: - Device related functions
extension PIAdapter {
    
    /**
    Public function to register a device in PI. 
    If the device already exists it will be updated.
    
    :param: device   PIDevice to be registered.
    :param: callback Returns a copy of the registered PIDevice upon task completion.
    */
    public func registerDevice(device: PIDevice, callback:(PIDevice)->()) {
        
        let endpoint = _configURL + "/devices"
        
        device.setRegistered(true)
        
        assert(device.name != nil, "PIDevice name cannot be registered as nil.")
        assert(device.type != nil, "PIDevice type cannot be registered as nil.")
        
        if device.data == nil {
            device.data = NSMutableDictionary()
        }
        
        if device.unencryptedData == nil {
            device.unencryptedData = NSMutableDictionary()
        }
        
        let deviceData = dictionaryToJSON(device.toDictionary())
        
        let request = buildRequest(endpoint, method: POST, body: deviceData)
        performRequest(request, callback: {response in
            
            self.printDebug("Register Response: \(response)")
            
            // If device doesn't exist:
            if let code = response["@code"] as? String {
                /**
                This is a safeguard to ensure that all fields are uploaded appropriatly
                Ideally the code should be:
                
                callback(MILPIDevice(dictionary: response))
                */
                
                self.updateDevice(device, callback: {newDevice in
                    callback(newDevice)
                })
                // If device does exist:
            } else if let headers = response["headers"] as? NSDictionary {
                if let location = headers["Location"] as? String {
                    self.getDevice(location, callback: {deviceData in
                        self.updateDeviceDictionary(location, dictionary: deviceData, device: device, callback: {newDevice in
                            callback(newDevice)
                        })
                    })
                }
            }
        })
    }
    
    /**
    Public function to unregister a device in PI.
    Sets device registered property to false and updates the device.
    
    :param: device   PIDevice to unregister.
    :param: callback Returns a copy of the unregistered PIDevice upon task completion.
    */
    public func unregisterDevice(device: PIDevice, callback:(PIDevice)->()) {
        
        device.setRegistered(false)
        updateDevice(device, callback: {newDevice in
            callback(newDevice)
        })
    }
    
    /**
    Public function to update a device in PI. 
    It pulls down the remote version of the device then modifies it for re-upload.
    
    :param: device   PIDevice to be updated.
    :param: callback Returns a copy of the updated PIDevice upon task completion.
    */
    public func updateDevice(device: PIDevice, callback:(PIDevice)->()) {
        
        assert(device.isRegistered(), "Cannot update an unregistered device.")
        
        var endpoint = _configURL + "/devices?rawDescriptor=" + device.getDescriptor()
        getDevice(endpoint, callback: {deviceData in
            endpoint = self._configURL + "/devices/" + (deviceData["@code"] as! String)
            self.updateDeviceDictionary(endpoint, dictionary: deviceData, device: device, callback: {newDevice in
                callback(newDevice)
            })
        })
    }
    
    /**
    Private function that modifies the remote device dictionary object with a local PIDevice and uploads it to PI.
    
    :param: endpoint   The device endpoint to update.
    :param: dictionary Current version of device in PI.
    :param: device     Local PIDevice used to update remote device.
    :param: callback   Returns the updated PIDevice object upon task completion.
    */
    private func updateDeviceDictionary(endpoint: String, dictionary: NSDictionary, device: PIDevice, callback:(PIDevice)->()) {
        
        var newDevice = NSMutableDictionary(dictionary: dictionary)
        
        newDevice.setObject(device.isRegistered(), forKey: device.JSON_REGISTERED_KEY)
        
        if device.isRegistered() {
            newDevice.setObject(device.name!, forKey: device.JSON_NAME_KEY)
            newDevice.setObject(device.type!, forKey: device.JSON_TYPE_KEY)
            newDevice.setObject(device.data!, forKey: device.JSON_DATA_KEY)
            newDevice.setObject(device.unencryptedData!, forKey: device.JSON_UNENCRYPTED_DATA_KEY)
        }
        
        let deviceJSON = self.dictionaryToJSON(newDevice)
        
        let request = self.buildRequest(endpoint, method: self.PUT, body: deviceJSON)
        self.performRequest(request, callback: {response in
            self.printDebug("Update Response: \(response)")
            if let code = response["@code"] as? String {
                callback(PIDevice(dictionary: response))
            }
        })
        
    }
    
    /**
    Public function to retrieve a device from PI using the device's code.
    
    :param: code     The device's code.
    :param: callback Returns the PIDevice upon task completion.
    */
    public func getDeviceByCode(code: String, callback:(PIDevice)->()) {
        
        let endpoint = _configURL + "/devices/" + code
        getDevice(endpoint, callback: {deviceData in
            let device = PIDevice(dictionary: deviceData)
            callback(device)
        })
    }
    
    /**
    Public function to retrice a device from PI using the device's descriptor.
    
    :param: descriptor The unhashed device descriptor. (Usually the UUID)
    :param: callback   Returns the PIDevice upon task completion.
    */
    public func getDeviceByDescriptor(descriptor: String, callback:(PIDevice)->()) {
        
        let endpoint = _configURL + "/devices?rawDescriptor=" + descriptor
        getDevice(endpoint, callback: {deviceData in
            let device = PIDevice(dictionary: deviceData)
            callback(device)
        })
        
    }
    
    /**
    Private function to get a device using either code of descriptor.
    
    :param: endpoint The Rest API endpoint of the device object.
    :param: callback Returns the dictionary object of the device upon task completion.
    */
    private func getDevice(endpoint: String, callback: (NSDictionary)->()) {
        
        let request = buildRequest(endpoint, method: GET, body: nil)
        performRequest(request, callback: {response in
            
            self.printDebug("Get Device Response: \(response)")
            
            var deviceData = response
            if let rows = response["rows"] as? NSArray {
                if rows.count > 0 {
                    deviceData = rows[0] as! NSDictionary
                } else {
                    return
                }
            }
            
            callback(deviceData)
            
        })
    }
    
    /**
    Public function to retrieve all registered and unregistered devices from PI.
    
    NOTE: Getting devices currently returns the first 100 devices.
    A future implementation should probably account for page size and number.
    
    :param: callback Returns an array of PIDevices upon task completion.
    */
    public func getAllDevices(callback:([PIDevice])->()) {
        
        let endpoint = _configURL + "/devices?pageSize=100"
        
        getDevices(endpoint, callback: {devices in
            callback(devices)
        })
    }
    
    /**
    Public function to retrieve only registered devices from PI.
    
    NOTE: Getting devices currently returns the first 100 devices.
    A future implementation should probably account for page size and number.
    
    :param: callback Returns an array of PIDevices upon task completion.
    */
    public func getRegisteredDevices(callback:([PIDevice])->()) {
        
        let endpoint = _configURL + "/devices?pageSize=100&registered=true"
        
        getDevices(endpoint, callback: {devices in
            callback(devices)
        })
    }
    
    /**
    Private function to handle getting multiple devices.
    
    :param: endpoint The Rest API endpoint of the devices.
    :param: callback Returns an array of PIDevices upon task completion.
    */
    private func getDevices(endpoint: String, callback:([PIDevice])->()) {
        
        let request = buildRequest(endpoint, method: GET, body: nil)
        performRequest(request, callback: {response in
            
            self.printDebug("Get Devices Response: \(response)")
            
            var devices: [PIDevice] = []
            if let rows = response["rows"] as? NSArray {
                for row in rows as! [NSDictionary] {
                    let device = PIDevice(dictionary: row)
                    devices.append(device)
                }
            }
            
            callback(devices)
        })
    }
}

// MARK: - Beacon related functions
extension PIAdapter {
    
    /**
    Public function to get all beacon proximity UUIDs.
    
    :param: callback Returns a String array of all beacon proximity UUIDs upon task completion.
    */
    public func getAllBeaconRegions(callback:([String]) -> ()) {
        
        let endpoint = _configURL + "/views/proximityUUID"
        
        let request = buildRequest(endpoint, method: GET, body: nil)
        performRequest(request, callback: {response in
            
            self.printDebug("Get All Beacon Regions Response: \(response)")
            
            if let regions = response["dataArray"] as? [String] {
                callback(regions)
            }
        })
        
    }
    
    /**
    Public function to get all beacons on a specific floor.
    
    :param: site     PI Site code
    :param: floor    PI Floor code
    :param: callback Returns an array of PIBeacons upon task completion.
    */
    public func getAllBeacons(site: String, floor: String, callback:([PIBeacon])->()) {
        
        // Swift cannot handle this complex of an expression without breaking it down.
        var endpoint =  _configURL + "/sites/" + site
        endpoint += "/floors/" + floor + "/beacons"
        
        let request = buildRequest(endpoint, method: GET, body: nil)
        performRequest(request, callback: {response in
            
            self.printDebug("Get Beacons Response: \(response)")
            
            var beacons: [PIBeacon] = []
            if let rows = response["rows"] as? NSArray {
                for row in rows as! [NSDictionary] {
                    let beacon = PIBeacon(dictionary: row)
                    beacons.append(beacon)
                }
            }
            
            callback(beacons)
        })
    }
    
    /**
    Public function to send a payload of all beacons ranged by the device back to PI.
    
    :param: beaconData Array containing all ranged beacons and the time they were detected.
    */
    public func sendBeaconPayload(beaconData:NSArray) {
        
        let endpoint = _baseURL + _beaconSegment + "tenants/" + _tenantCode + "/orgs/" + _orgCode
        let notificationMessage = NSDictionary(object: beaconData, forKey: "bnm")
        
        let notificationData = dictionaryToJSON(notificationMessage)
        
        self.printDebug("Sending Beacon Payload: \(notificationMessage)")
        
        let request = buildRequest(endpoint, method: POST, body: notificationData)
        performRequest(request, callback: {response in
            self.printDebug("Sent Beacon Payload Response: \(response)")
        })
    }
}

// MARK: - Zone related functions
extension PIAdapter {
    
    /**
    Public function to retrieve all zones in a floor.
    
    :param: site     PI Site code
    :param: floor    PI Floor code
    :param: callback Returns an array of PIZones upon task completion.
    */
    public func getAllZones(site: String, floor: String, callback:([PIZone])->()) {
        
        // Swift cannot handle this complex of an expression without breaking it down.
        var endpoint =  _configURL + "/sites/" + site
        endpoint += "/floors/" + floor + "/zones"
        
        let request = buildRequest(endpoint, method: GET, body: nil)
        performRequest(request, callback: {response in
            
            self.printDebug("Get Zones Response: \(response)")
            
            var zones: [PIZone] = []
            if let rows = response["rows"] as? NSArray {
                for row in rows as! [NSDictionary] {
                    let zone = PIZone(dictionary: row)
                    zones.append(zone)
                }
            }
            
            callback(zones)
        })
    }
}

// MARK: - Map related functions
extension PIAdapter {
    
    /**
    Public function to retrieve a floor's map image.
    
    :param: site     PI Site code
    :param: floor    PI Floor code
    :param: callback Returns a UIImage of the map upon task completion.
    */
    public func getMap(site: String, floor: String, callback:(UIImage)->()) {
        
        // Swift cannot handle this complex of an expression without breaking it down.
        var endpoint =  _configURL + "/sites/" + site
        endpoint += "/floors/" + floor + "/map"
        
        let request = buildRequest(endpoint, method: GET, body: nil)
        performRequest(request, callback: {response in
            
            self.printDebug("Get Map Response: \(response)")
            
            if let data = response["rawData"] as? NSData {
                if let image = UIImage(data: data) {
                    callback(image)
                } else {
                    self.printDebug("Invalid Image: \(data)")
                }
            } else {
                self.printDebug("Invalid Data")
            }
        })
        
    }
}

// MARK: - Org related functions
extension PIAdapter {
    
    /**
    Public function to retrive the org from PI.
    
    :param: callback Returns the raw dictionary from the Rest API upon task completion.
    */
    public func getOrg(callback:(PIOrg)->()) {
        
        var endpoint =  _configURL
        
        let request = buildRequest(endpoint, method: GET, body: nil)
        performRequest(request, callback: {response in
            
            self.printDebug("Get Org Response: \(response)")
            
            let org = PIOrg(dictionary: response)
            
            callback(org)
        })
    }
}

// MARK: - Site related functions
extension PIAdapter {
    
    /**
    Public function to get all sites within the org.
    
    :param: callback Returns a dictionary with site code as the keys and site name as the values.
    */
    public func getAllSites(callback:([String: String])->()) {
        
        var endpoint =  _configURL + "/sites"
        
        let request = buildRequest(endpoint, method: GET, body: nil)
        performRequest(request, callback: {response in
            
            self.printDebug("Get Sites Response: \(response)")
            
            var sites: [String: String] = [:]
            if let rows = response["rows"] as? NSArray {
                for row in rows as! [NSDictionary] {
                    if let site = row["@code"] as? String {
                        if let name = row["name"] as? String {
                            sites[site] = name
                        }
                    }
                }
            }
            
            callback(sites)
        })
    }
}

// MARK: - Floor related functions
extension PIAdapter {
    
    /**
    Public function to get all floors in a site.
    
    :param: site     PI Site code
    :param: callback Returns a dictionary with floor code as the keys and floor name as the values.
    */
    public func getAllFloors(site: String, callback:([String: String])->()) {
        
        var endpoint =  _configURL + "/sites/" + site + "/floors"
        
        let request = buildRequest(endpoint, method: GET, body: nil)
        performRequest(request, callback: {response in
            
            self.printDebug("Get Floors Response: \(response)")
            
            var floors: [String: String] = [:]
            if let rows = response["rows"] as? NSArray {
                for row in rows as! [NSDictionary] {
                    if let floor = row["@code"] as? String {
                        if let name = row["name"] as? String {
                            floors[floor] = name
                        }
                    }
                }
            }
            
            callback(floors)
        })
    }
}

// MARK: - Utility functions
extension PIAdapter {
    
    /**
    Private function to build an http/s request
    
    :param: endpoint The URL to connect to.
    :param: method   The http method to use for the request.
    :param: body     (Optional) The body of the request.
    
    :returns: A built NSURLRequest to execute.
    */
    private func buildRequest(endpoint:String, method:String, body: NSData?) -> NSURLRequest {
        
        if let url = NSURL(string: endpoint) {
            
            let request = NSMutableURLRequest(URL: url)
            
            request.HTTPMethod = method
            request.addValue(_authorization, forHTTPHeaderField: _httpAuthorizationHeader)
            request.addValue(_contentTypeJSON, forHTTPHeaderField: _httpContentTypeHeader)
            
            if let bodyData = body {
                request.HTTPBody = bodyData
            }
            
            return request
        } else {
            printDebug("Invalid URL: \(endpoint)")
        }
        
        return NSURLRequest()
        
    }
    
    /**
    Private function to perform a URL request.
    Will always massage response data into a dictionary.
    
    :param: request  The NSURLRequest to perform.
    :param: callback Returns an NSDictionary of the response on task completion.
    */
    private func performRequest(request:NSURLRequest, callback:(NSDictionary!)->()) {
        
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request, completionHandler: {data, response, error in
            
            if (error != nil) {
                print(error)
            } else {
                if let responseData = data {
                    
                    var error: NSError?
                    if let json = NSJSONSerialization.JSONObjectWithData(responseData, options: NSJSONReadingOptions.MutableLeaves, error: &error) as? NSDictionary {
                        if (error != nil) {
                            let dataString = NSString(data: responseData, encoding: NSUTF8StringEncoding)
                            self.printDebug("Could not parse response. " + (dataString as! String) + "\(error)")
                        } else {
                            callback(json)
                        }
                    } else if let json = NSJSONSerialization.JSONObjectWithData(responseData, options: NSJSONReadingOptions.MutableLeaves, error: &error) as? NSArray {
                        if (error != nil) {
                            let dataString = NSString(data: responseData, encoding: NSUTF8StringEncoding)
                            self.printDebug("Could not parse response. " + (dataString as! String) + "\(error)")
                        } else {
                            let returnVal = NSDictionary(object: json, forKey: "dataArray")
                            callback(returnVal)
                        }
                    } else {
                        let returnVal = NSDictionary(object: responseData, forKey: "rawData")
                        callback(returnVal)
                    }
                    
                } else {
                    self.printDebug("No response data.")
                }
                
            }
        })
        task.resume()
    }
    
    /**
    Private function to convert a dictionary to a JSON object.
    
    :param: dictionary The dictionary to convert.
    
    :returns: An NSData object containing the raw JSON of the dictionary.
    */
    private func dictionaryToJSON(dictionary: NSDictionary) -> NSData {
        var error: NSError?
        if let deviceJSON = NSJSONSerialization.dataWithJSONObject(dictionary, options: NSJSONWritingOptions.allZeros, error: &error) {
            if (error != nil) {
                printDebug("Could not convert dictionary object to JSON. \(error)")
            } else {
                return deviceJSON
            }
            
        } else {
            printDebug("Could not convert dictionary object to JSON.")
        }
        
        return NSData()
        
    }
    
    /**
    Public function to print statements in the console when debug is enabled.
    Also appends the TAG to the message.
    
    :param: message The message to print in the console.
    */
    public func printDebug(message:String) {
        if _debug {
            println(TAG + message)
        }
    }
}