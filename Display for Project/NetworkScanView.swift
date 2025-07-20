import SwiftUI
import Foundation
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

struct DetectedDevice: Identifiable, Codable {
    let id: UUID
    var name: String   
    let ipAddress: String
    var animalWeight: Double
    var animalName: String
    var animalDailyGain: Double
    var AnimalGender: String
    var AnimalSpecies: String

    init(id: UUID = UUID(), name: String, ipAddress: String, animalWeight: Double, animalName: String, animalDailyGain: Double, AnimalGender:String, AnimalSpecies: String) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.animalWeight = animalWeight
        self.animalName = animalName
        self.animalDailyGain = animalDailyGain
        self.AnimalGender = AnimalGender
        self.AnimalSpecies = AnimalSpecies
    }
}


class DevicesStore: ObservableObject {
    @Published var devices: [DetectedDevice] = []
    
    private let storageKey = "storedDevices"
    
    init() {
        load()
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DetectedDevice].self, from: data) {
            self.devices = decoded
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func add(device: DetectedDevice) {
        guard !devices.contains(where: { $0.ipAddress == device.ipAddress }) else { return }
        devices.append(device)
        save()
    }
    
    func clear() {
        devices.removeAll()
        save()
    }
}

struct NetworkScanView: View {
    @StateObject private var store = DevicesStore()
    @State private var isScanning = false
    @AppStorage("ipSubnet") private var ipSubnet: String = "192.168.1."
    @State private var pollingTimers: [UUID: Timer] = [:]
    @State private var wifiStrengths: [UUID: String] = [:]
    @State private var notificationPermissionGranted = false
    @State private var feedingStates: [UUID: Bool] = [:]
    @AppStorage("DarkModeEnabled") private var isEnabled = false

    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    
    var body: some View {
        VStack {
            List(store.devices) { device in
                NavigationLink(destination: ArduinoControllerView(device: device, store: store)) {
                    NetworkScanControlRow(
                        title: device.name,
                        data: wifiStrengths[device.id] ?? "Unknown",
                        subtitle: device.ipAddress
                    )
                }
                .listRowBackground(Color(.secondarySystemBackground))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .scrollContentBackground(.hidden)
            
            Divider()
            
            Toggle(isOn: $isEnabled) {
                Text(isEnabled ? "Disable Dark Mode" : "Enable Dark Mode")
                    .font(.headline)
            }
            .padding()
            NavigationLink(destination: ArduinoControllerView(
                device: DetectedDevice(
                    name: "Demo Feeder",
                    ipAddress: "192.168.1.100",
                    animalWeight: 250.0,
                    animalName: "Demo Cow",
                    animalDailyGain: 1.2,
                    AnimalGender: "Female",
                    AnimalSpecies: "Cattle"
                ),
                store: store
            )) {
                Text("Demo Mode")
                    .font(.headline)
                    .padding()
            }
        }
        .navigationTitle("Feeders")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    scanForArduino()
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Find New Feeders")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isScanning) {
            ScanningView()
        }
        .onAppear {
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
            requestNotificationPermission()

            if let subnet = getLocalIPv4Subnet() {
                ipSubnet = subnet + "."
            }
            updatePollingTimers()
        }
        .onDisappear {
            pollingTimers.values.forEach { $0.invalidate() }
            pollingTimers.removeAll()
        }
        .preferredColorScheme(isEnabled ? .dark : .light)

        .preferredColorScheme(isEnabled ? .dark : .light)
    }
    
    func updatePollingTimers() {
        pollingTimers.values.forEach { $0.invalidate() }
        pollingTimers.removeAll()
        
        guard !store.devices.isEmpty else { return }
        
        for device in store.devices {
            let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                fetchFeededWeight(for: device)
            }
            pollingTimers[device.id] = timer
        }
    }
    
    func scanForArduino() {
        guard !isScanning else { return }
        isScanning = true
        
        DispatchQueue.global(qos: .background).async {
            let group = DispatchGroup()
            var foundDevices = [DetectedDevice]()
            
            for i in 1...254 {
                let testIP = "\(ipSubnet)\(i)"
                guard let url = URL(string: "http://\(testIP)/getName") else { continue }
                
                group.enter()
                var request = URLRequest(url: url)
                request.timeoutInterval = 2
                
                let task = session.dataTask(with: request) { data, response, error in
                    defer { group.leave() }
                    
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let name = json["name"] as? String {
                        
                        let animalName = json["animalName"] as? String ?? "Unknown"
                        let animalWeightStr = json["animalWeight"] as? String ?? "0"
                        let animalDailyGainStr = json["animalDailyGain"] as? String ?? "0"
                        let animalGender = json["animalGender"] as? String ?? "Unknown"
                        let animalSpecies = json["animalSpecies"] as? String ?? "Unknown"

                        let animalWeight = Double(animalWeightStr) ?? 0.0
                        let animalDailyGain = Double(animalDailyGainStr) ?? 0.0

                        let device = DetectedDevice(
                            name: name,
                            ipAddress: testIP,
                            animalWeight: animalWeight,
                            animalName: animalName,
                            animalDailyGain: animalDailyGain,
                            AnimalGender: animalGender,
                            AnimalSpecies: animalSpecies
                        )
                        foundDevices.append(device)
                    }

                }
                task.resume()
            }
            
            group.notify(queue: .main) {
                for device in foundDevices {
                    store.add(device: device)
                }
                isScanning = false
                updatePollingTimers()
            }
        }
    }
    
    func fetchFeededWeight(for device: DetectedDevice) {
        guard let url = URL(string: "http://\(device.ipAddress)/getFeededWeight") else { return }
        
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    print("[\(device.ipAddress)] Error: \(error.localizedDescription)")
                    wifiStrengths[device.id] = "Disconnected"
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let _ = json["FeededWeight"] as? String,
                      let feedStatusStr = json["FeedingStatus"] as? String,
                      let sw = json["WifiStatus"] as? String else {
                    print("[\(device.ipAddress)] Invalid or missing data")
                    wifiStrengths[device.id] = "Unknown"
                    return
                }
                
                let feedingActive = (feedStatusStr.lowercased() == "true")
                
                if feedingActive {
                    if feedingStates[device.id] != true {
                        feedingStates[device.id] = true
                        if notificationPermissionGranted {
                            sendNotification(
                                title: "Feeding Active",
                                subtitle: "Device \(device.name) is currently feeding."
                            )
                        }
                    }
                } else {
                    feedingStates[device.id] = false
                }
                
                if let swInt = Int(sw) {
                    if swInt >= -50 {
                        wifiStrengths[device.id] = "Signal Strength: Excellent"
                    } else if swInt < -50 && swInt > -70 {
                        wifiStrengths[device.id] = "Signal Strength: Fair"
                    } else if swInt <= -70 {
                        wifiStrengths[device.id] = "Signal Strength: Poor"
                    }
                } else {
                    wifiStrengths[device.id] = "Signal Strength: Unknown"
                }
            }
        }.resume()
    }
    
    func getLocalIPv4Subnet() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                guard let interface = ptr?.pointee else { break }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET),
                   let name = String(cString: interface.ifa_name, encoding: .utf8),
                   name == "en0" {
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
                ptr = interface.ifa_next
            }
            freeifaddrs(ifaddr)
        }

        guard let ip = address else { return nil }
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return parts.prefix(3).joined(separator: ".")
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification permission granted")
                    notificationPermissionGranted = true
                } else {
                    print("Notification permission denied")
                    notificationPermissionGranted = false
                }
            }
        }
    }
    
    func sendNotification(title: String, subtitle: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled: \(title) - \(subtitle)")
            }
        }
    }
}

struct NetworkScanControlRow: View {
    let title: String
    let data: String
    var subtitle: String? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(data)
                .font(.headline)
                .foregroundColor(
                    (data.lowercased().contains("unknown") || data.lowercased().contains("disconnected"))
                    ? .red
                    : .primary
                )
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
