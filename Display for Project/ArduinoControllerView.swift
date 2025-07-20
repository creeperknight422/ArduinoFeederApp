import SwiftUI
import PhotosUI

struct ArduinoControllerView: View {
    let device: DetectedDevice

    @AppStorage("ipAddress") private var ipAddress: String = ""
    @AppStorage("savedFeedingTime") private var savedTime: Double = 0
    @AppStorage("feededWeight") private var feededWeight: String = "-"
    @AppStorage("statusMessage") private var statusMessage: String = ""
    @AppStorage("WifiStrength") private var WifiStrength = ""
    @State private var feededWeightTimer: Timer? = nil
    @State private var deviceImage: Image? = nil
    @ObservedObject var store: DevicesStore
    @Environment(\.presentationMode) var presentationMode
    @State private var showingImagePicker = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil

    @State private var isDeviceDataActive = false
    private var imageKey: String {
        "deviceImage_" + device.ipAddress
    }
    @State private var hasEverConnected = false
    @State private var connectionStatus = ""

    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        return URLSession(configuration: config)
    }()

    var wifiSignalColor: Color {
        switch WifiStrength {
        case let str where str.contains("Excellent"):
            return .green
        case let str where str.contains("Fair"):
            return .orange
        case let str where str.contains("Poor"):
            return .red
        default:
            return .gray
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    if let image = deviceImage {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 220)
                            .cornerRadius(20)
                            .overlay(
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "pencil")
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .padding(8)
                                .onTapGesture {
                                    showingImagePicker = true
                                },
                                alignment: .bottomTrailing
                            )
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 220)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(20)
                            .overlay(
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "pencil")
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .padding(8)
                                .onTapGesture {
                                    showingImagePicker = true
                                },
                                alignment: .bottomTrailing
                            )
                    }
                }
                .photosPicker(isPresented: $showingImagePicker, selection: $selectedItem, matching: .images)
                .onChange(of: selectedItem) { newItem in
                    guard let newItem = newItem else { return }
                    Task {
                        do {
                            if let data = try await newItem.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                selectedImage = uiImage
                                deviceImage = Image(uiImage: uiImage)
                                saveImage(uiImage)
                            }
                        } catch {
                            print("Failed to load image: \(error.localizedDescription)")
                        }
                    }
                }

                Text(device.name)
                    .font(.title2)
                    .fontWeight(.bold)
                VStack(spacing: 8) {
                    HStack {
                        Label("Status", systemImage: "wifi")
                            .font(.headline)
                        Spacer()
                        Text(connectionStatus)
                            .foregroundColor(connectionStatus == "Connected" ? .green : .red)
                            .fontWeight(.semibold)
                    }
                    if connectionStatus == "Connected" {
                        HStack {
                            Label("Wi-Fi Signal", systemImage: "wifi.exclamationmark")
                                .font(.headline)
                            Spacer()
                            Text(WifiStrength)
                                .foregroundColor(wifiSignalColor)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(15)
                .padding(.horizontal)

                VStack(spacing: 16) {
                    NavigationLink(destination: SetFeedingTime()) {
                        ControlRow(iconName: "clock", title: "Scheduled Feeding Time", subtitle: formattedTime(from: savedTime))
                            .foregroundColor(.black)
                    }

                    NavigationLink(destination: ManualFeed()) {
                        ControlRow(iconName: "bolt.fill", title: "Manual Feed")
                            .foregroundColor(.black)
                    }

                    NavigationLink(
                        destination: DeviceData(device: device, store: store, isActive: $isDeviceDataActive),
                        isActive: $isDeviceDataActive
                    ) {
                        ControlRow(iconName: "cpu", title: "Feeder Data")
                    }


                    NavigationLink(destination: AnimalData(device: device, store: store)) {
                        ControlRow(iconName: "pawprint.fill", title: "Animal Data")
                            .foregroundColor(.black)
                    }

                    NavigationLink(destination: FeedLogView(device: device)) {
                        ControlRow(iconName: "list.bullet.rectangle", title: "Feed Log")
                            .foregroundColor(.black)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .padding(.horizontal)

                Spacer()
            }
        }
        .navigationTitle("Controller")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            ipAddress = "http://" + device.ipAddress
            loadImage()
            startFeededWeightTimer()
        }
        .onDisappear {
            feededWeightTimer?.invalidate()
            feededWeightTimer = nil
        }
    }

    func startFeededWeightTimer() {
        feededWeightTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            fetchFeededWeight()
        }
    }

    func loadImage() {
        if let data = UserDefaults.standard.data(forKey: imageKey),
           let uiImage = UIImage(data: data) {
            deviceImage = Image(uiImage: uiImage)
        }
    }

    func saveImage(_ uiImage: UIImage) {
        if let data = uiImage.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(data, forKey: imageKey)
        }
    }

    func formattedTime(from timeInterval: Double) -> String {
        let date = Date(timeIntervalSince1970: timeInterval)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func fetchValue(from endpoint: String, completion: @escaping ([String: Any]) -> Void) {
        guard let url = URL(string: ipAddress + endpoint) else { return }

        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    completion(json)
                }
            }
        }.resume()
    }

    func fetchFeededWeight() {
        guard let url = URL(string: ipAddress + "/getFeededWeight") else { return }

        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    connectionStatus = "Disconnected"
                    return
                }
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fw = json["FeededWeight"] as? String,
                   let sw = json["WifiStatus"] as? String {
                    connectionStatus = "Connected"
                    feededWeight = fw
                    WifiStrength = signalDescription(for: sw)
                    if !hasEverConnected {
                        hasEverConnected = true
                    }
                }
            }
        }.resume()
    }

    func signalDescription(for rawSignal: String) -> String {
        guard let swInt = Int(rawSignal) else { return "Unknown" }
        if swInt >= -50 { return "Excellent" }
        else if swInt < -50 && swInt > -70 { return "Fair" }
        else { return "Poor" }
    }
}

struct ControlRow: View {
    let iconName: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(.primary)
                .frame(width: 30)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
