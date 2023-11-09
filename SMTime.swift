import Foundation


class SMTime {
    
    enum Error {
        case smallTimeDifferenceError, serverError, parsingError, systemDateChanged, none
        func message() -> String {
            switch self {
            case .smallTimeDifferenceError: return "Please contract your system administrator."
            case .serverError: return "Server error. Please try again later."
            case .parsingError: return "Couldn't read data from server. Please try again later."
            case .systemDateChanged: return "Goto Settings>>General>>Date & Time and enable Set Automatically."
            case .none: return "Date not altered."
            }
        }
    }
    
    
    //MARK: - Public methods
    
    static func getTime(block: @escaping (_ success: Bool, _ date: Date, _ message: String) -> Void) {
        if isSystemTimeChanged() {
            SMTime.getTimeFromServerAndValidateDate { (success, ttError) in
                if success {
                    let totalTimeInterval = kernelBootTime() + kernelUptime()
                    let date = Date(timeIntervalSince1970: totalTimeInterval)
                    
                    let differenceTime = date.timeIntervalSince(Date())
                    let accurateDate =  date.addingTimeInterval(-differenceTime)
                    
                    SMUserDefault.set(data: kernelBootTime() - differenceTime, forKey: .actualBootTimeInterval)
                    SMUserDefault.set(data: kernelBootTime(), forKey: .defaultBootTimeInterval)
                    
                    DispatchQueue.main.async { block(true, accurateDate, ttError.message()) }
                } else {
                    DispatchQueue.main.async { block(false, Date(), ttError.message()) }
                }
            }
        } else {
            DispatchQueue.main.async { block(true, Date(), Error.none.message()) }
        }
    }
    
    private static func isSystemTimeChanged() -> Bool {
        if let defaultBootTimeInterval = SMUserDefault.get(forKey: .defaultBootTimeInterval) as? TimeInterval {
            let validTime = abs(defaultBootTimeInterval - kernelBootTime()) <= 30
            
            return !validTime
        }
        return true
    }
    
    static func upTime() -> Date {
        return Date(timeIntervalSince1970: kernelUptime())
    }
    
    
    
    
    
    //MARK: - Private methods
    
    private static func kernelBootTime() -> TimeInterval {
        var mib = [ CTL_KERN, KERN_BOOTTIME ]
        var bootTime = timeval()
        var bootTimeSize = MemoryLayout<timeval>.size
        
        if 0 != sysctl(&mib, UInt32(mib.count), &bootTime, &bootTimeSize, nil, 0) {
            fatalError("Could not get boot time, errno: \(errno)")
        }
        
        let timeInterval = TimeInterval(bootTime.tv_sec) + TimeInterval(bootTime.tv_usec/1000000)
        
        return timeInterval
    }
    
    
    private static func kernelUptime() -> TimeInterval {
        var currentTime = time_t()
        var bootTime    = timeval()
        var mib         = [CTL_KERN, KERN_BOOTTIME]
        
        var size = MemoryLayout<timeval>.size
        let result = sysctl(&mib, u_int(mib.count), &bootTime, &size, nil, 0)
        if result != 0 {
            return 0
        }
        
        time(&currentTime)
        let uptime = currentTime - bootTime.tv_sec
        
        return TimeInterval(uptime)
    }
    
    
    private static func getTimeFromServerAndValidateDate(block: @escaping (_ success: Bool, _ message: SMTime.Error) -> Void) {
        let smTimeZone = TimeZone.current.identifier
        
        let url = URL(string: "https://santoshm.com.np/englishdate/index.php?timezone=\(smTimeZone)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let session = URLSession.shared
        
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async { block(false, .serverError) }
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                DispatchQueue.main.async { block(false, .serverError) }
                return
            }
            
            guard (200...299).contains(response.statusCode) else {
                DispatchQueue.main.async { block(false, .serverError) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { block(false, .parsingError) }
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let jsonDict = json as? [String: Any], let date = jsonDict["date"] as? String {
                    let serverDate = date.smToDate() ?? Date()
                    print("Date: \(serverDate)")
                    
                    if abs(serverDate.minutes(from: Date())) <= 2 {
                        DispatchQueue.main.async { block(true, .none) }
                    }else{
                        DispatchQueue.main.async { block(false, .systemDateChanged) }
                    }
                }
            } catch {
                DispatchQueue.main.async { block(false, .parsingError) }
            }
        }
        
        task.resume()
    }
    
}

class SMUserDefault
{
    enum defaultType:String {
        // String
        case actualBootTimeInterval = "com.cninfotech.actualBootTimeInterval"
        case defaultBootTimeInterval = "com.cninfotech.defaultBootTimeInterval"
    }
    
    class func set(data:Any, forKey :defaultType) {
        UserDefaults().setValue(data, forKey: forKey.rawValue)
        UserDefaults().synchronize()
    }
    
    class func get(forKey key:defaultType) -> Any? {
        return UserDefaults().object(forKey: key.rawValue)
    }
    
    class func isAvailable(forKey key:defaultType) -> Bool {
        guard let _ = UserDefaults().object(forKey: key.rawValue) else { return false }
        return true
    }
    
    class func clear(_ type:defaultType? = nil) {
        if let _type = type {
            /*   Clean specific NSUserDefault data  */
            UserDefaults().removeObject(forKey: _type.rawValue)
        }else{
            /*   Clean all NSUserDefault datas   */
            guard let appDomain = Bundle.main.bundleIdentifier else { return }
            UserDefaults().removePersistentDomain(forName: appDomain)
        }
    }
    
}



extension String {
    func smToDate() -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd hh:mm:ss a"
        return dateFormatter.date(from: self) ?? nil
    }
}

extension Date {
    func minutes(from date: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0
    }
}
