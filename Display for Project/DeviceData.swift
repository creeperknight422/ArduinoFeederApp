import SwiftUI

struct DeviceData: View {
    let device: DetectedDevice
    @ObservedObject var store: DevicesStore
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("ipAddress") private var ipAddress: String = ""
    @State private var editableName: String

    @AppStorage("storage") private var storage: String = "-"
    @AppStorage("feededWeight") private var feededWeight: String = "-"
    @AppStorage("statusMessage") private var statusMessage: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @AppStorage("DarkModeEnabled") private var isEnabled = false
    @Binding var isActive: Bool
    
    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        return URLSession(configuration: config)
    }()
    
    init(device: DetectedDevice, store: DevicesStore, isActive: Binding<Bool>) {
        self.device = device
        self.store = store
        self._isActive = isActive
        self._editableName = State(initialValue: device.name)
    }

    var body: some View {
        Form {
            Section(header: Text("Device Info")) {
                HStack {
                    Text("Name")
                        .font(.headline)
                    Spacer()
                    TextField("Device Name", text: $editableName, onCommit: {
                        updateDeviceName(editableName)
                        setName(editableName)
                    })
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .submitLabel(.done)
                }

                DeviceDataControlRow(title: "Storage", data: storage)
                DeviceDataControlRow(title: "IP Address", data: ipAddress)
            }
            .listRowBackground(Color(.secondarySystemBackground))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            
            Section {
                NavigationLink(destination: DiagnosticsView()) {
                    DeviceDataControlRow2(title: "Troubleshoot Screen")
                }
                
                Button(action: {
                    sendCommand("/TareScale")
                }) {
                    Text("Tare Scale")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    store.devices.removeAll { $0.id == device.id }
                    store.save()
                    isActive = false
                }) {
                    DeviceDataControlRow2(title: "Forget/Disconnect")
                        .foregroundColor(.red)
                }
                .alert(isPresented: $showAlert) {
                    Alert(title: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
                .buttonStyle(.borderless)
            }
            .listRowBackground(Color(.secondarySystemBackground))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .navigationTitle("Feeder Data")
        .preferredColorScheme(isEnabled ? .dark : .light)
        .scrollContentBackground(.hidden)
    }
    
    func updateDeviceName(_ newName: String) {
        if let index = store.devices.firstIndex(where: { $0.id == device.id }) {
            store.devices[index].name = newName
            store.save()
        }
    }
    
    func setName(_ value: String) {
        sendCommand("/setName?value=\(value)")
    }
    
    func sendCommand(_ path: String) {
        guard let url = URL(string: ipAddress + path) else {
            statusMessage = "Invalid URL"
            return
        }

        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    switch error.code {
                    case NSURLErrorTimedOut:
                        statusMessage = "Device timed out, please reset device"
                        alertMessage = "Tare Failed"
                        showAlert = true
                    case NSURLErrorNotConnectedToInternet:
                        statusMessage = "No internet connection. Please check your Phone's internet"
                        alertMessage = "Tare Failed"
                        showAlert = true
                    case NSURLErrorNetworkConnectionLost:
                        statusMessage = "Feeder has lost internet, please reconnect"
                        alertMessage = "Tare Failed"
                        showAlert = true
                    default:
                        statusMessage = "Send failed: \(error.localizedDescription)"
                        alertMessage = "Tare Failed"
                        showAlert = true
                    }
                } else {
                    statusMessage = "Command \(path) sent successfully"
                    alertMessage = "Scale Tared"
                    showAlert = true
                }
            }
        }.resume()
    }
}

struct DeviceDataControlRow: View {
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
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct DeviceDataControlRow2: View {
    let title: String
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
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
