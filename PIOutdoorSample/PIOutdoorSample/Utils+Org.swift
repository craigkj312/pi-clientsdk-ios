/**
*  PIOutdoorSample
*  Utils+Org.swift
*
*  Performs all communication to the PI Rest API.
*
*  © Copyright 2016 IBM Corp.
*
*  Licensed under the Presence Insights Client iOS Framework License (the "License");
*  you may not use this file except in compliance with the License. You may find
*  a copy of the license in the license.txt file in this package.
*
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS,
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*  See the License for the specific language governing permissions and
*  limitations under the License.
**/

import UIKit
import MBProgressHUD
import CocoaLumberjack
import PIOutdoorSDK
import SSKeychain

extension Utils {


	static func createPIOrg(hostname:String,tenantCode:String,vc:UIViewController,completionHandler: ((String?) -> Void)? = nil ) {


		let service = piGeofencingManager.service
		let orgName = UIDevice.currentDevice().name + "-" + NSUUID().UUIDString
		DDLogVerbose("Start PIServiceCreateOrgRequest: \(orgName)")
		
		let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
		appDelegate.postSlack("\(UIDevice.currentDevice().name) : Refresh, asking a new org!")

		let request = PIServiceCreateOrgRequest(orgName:orgName) { response in
			switch response.result {
			case .OK?:
				DDLogVerbose("PIServiceCreateOrgRequest OK \(response.orgCode)")
				guard let orgCode = response.orgCode else {
					DDLogError("PIServiceCreateOrgRequest Missing org code",asynchronous:false)
					assertionFailure("Programming error")
					completionHandler?(nil)
					return
				}
				appDelegate.postSlackCreateOrg(orgCode)
				var json =  [String:AnyObject]()
				json["orgCode"] = orgCode
				guard let data = try? NSJSONSerialization.dataWithJSONObject(json, options: []) else {
					DDLogError("Programming Error",asynchronous:false)
					completionHandler?(nil)
					return
				}

				SSKeychain.setPasswordData(data, forService: hostname, account: tenantCode)
				piGeofencingManager.service.orgCode = orgCode

			case .Cancelled?:
				DDLogVerbose("PIServiceCreateOrgRequest cancelled")
			case let .Error(error)?:
				DDLogError("PIServiceCreateOrgRequest error \(error)",asynchronous:false)
			case let .Exception(error)?:
				DDLogError("PIServiceCreateOrgRequest exception \(error)",asynchronous:false)
			case let .HTTPStatus(status, _)?:
				DDLogError("PIServiceCreateOrgRequest status \(status)",asynchronous:false)
			case nil:
				DDLogError("PIServiceCreateOrgRequest No Result!",asynchronous:false)
				assertionFailure("Programming Error")
				break
			}
			if let orgCode = piGeofencingManager.service.orgCode {
				let alertController = UIAlertController(
					title: NSLocalizedString("Alert.OrgCreation.Title",comment:""),
					message: NSLocalizedString("Alert.OrgCreation.Message",comment:""),
					preferredStyle: .Alert)

				let okAction = UIAlertAction(title: NSLocalizedString("OK",comment:""), style: .Default){ (action) in
					dispatch_async(dispatch_get_main_queue()) {
						completionHandler?(orgCode)
						piGeofencingManager.synchronize()
					}
				}
				alertController.addAction(okAction)


				vc.presentViewController(alertController, animated: true, completion: nil)
			} else {
				let alertController = UIAlertController(
					title: NSLocalizedString("Alert.OrgCreation.Error.Title",comment:""),
					message: NSLocalizedString("Alert.OrgCreation.Error.Message",comment:""),
					preferredStyle: .Alert)

				let okAction = UIAlertAction(title: NSLocalizedString("OK",comment:""), style: .Default){ (action) in
					dispatch_async(dispatch_get_main_queue()) {
						completionHandler?(nil)
					}
				}
				alertController.addAction(okAction)


				vc.presentViewController(alertController, animated: true, completion: nil)


			}
		}
		service.executeRequest(request)

	}
}