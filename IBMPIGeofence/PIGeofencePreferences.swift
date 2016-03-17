/**
*  IBMPIGeofence
*  PIGeofencePreferences.swift
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

import Foundation


private let kLastSynchronizeKey = "com.ibm.pi.LastSynchronize"
private let kLastSynchronizeErrorKey = "com.ibm.pi.LastSynchronizeError"
private let kErrorDownloadCountKey = "com.ibm.pi.downloads.errorCount"

struct PIGeofencePreferences {
	static var lastSynchronizeDate:NSDate? {
		set {
			if let newValue = newValue {
				PIUnprotectedPreferences.sharedInstance.setObject(newValue, forKey: kLastSynchronizeKey)
			} else {
				PIUnprotectedPreferences.sharedInstance.removeObjectForKey(kLastSynchronizeKey)
			}
		}
		get {
			return PIUnprotectedPreferences.sharedInstance.objectForKey(kLastSynchronizeKey) as? NSDate
		}
	}

	static var lastSynchronizeErrorDate:NSDate? {
		set {
			if let newValue = newValue {
				PIUnprotectedPreferences.sharedInstance.setObject(newValue, forKey: kLastSynchronizeErrorKey)
			} else {
				PIUnprotectedPreferences.sharedInstance.removeObjectForKey(kLastSynchronizeErrorKey)
			}
		}
		get {
			return PIUnprotectedPreferences.sharedInstance.objectForKey(kLastSynchronizeErrorKey) as? NSDate
		}
	}

	static var downloadErrorCount:Int? {
		set {
			if let newValue = newValue {
				PIUnprotectedPreferences.sharedInstance.setInteger(newValue, forKey: kErrorDownloadCountKey)
			} else {
				PIUnprotectedPreferences.sharedInstance.removeObjectForKey(kErrorDownloadCountKey)
			}
		}
		get {
			return PIUnprotectedPreferences.sharedInstance.integerForKey(kErrorDownloadCountKey)
		}
	}

	static func synchronize() {
		PIUnprotectedPreferences.sharedInstance.synchronize()
	}
}