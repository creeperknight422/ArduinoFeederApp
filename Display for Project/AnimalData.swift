import SwiftUI

struct EditableDeviceDataControlRow: View {
    let title: String
    @Binding var textValue: String
    var pickerOptions: [String]? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            if let options = pickerOptions {
                Picker("", selection: $textValue) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .foregroundColor(.primary)
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: 150)
            } else {
                TextField("", text: $textValue)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .frame(maxWidth: 150)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct AnimalData: View {
    let device: DetectedDevice
    @ObservedObject var store: DevicesStore

    @State private var localWeightText: String = ""
    @State private var localDailyGainText: String = ""
    @State private var editableName: String
    @State private var editableGender: String
    @State private var editableSpecies: String

    @State private var weight: Double
    @State private var dailyGain: Double

    let genderOptions = ["Male", "Female"]
    let typeOptions = ["Cow", "Pig", "Sheep", "Chicken", "Goat", "Other"]

    let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        return nf
    }()

    @AppStorage("ipAddress") private var ipAddress: String = ""
    @AppStorage("statusMessage") private var statusMessage: String = ""

    init(device: DetectedDevice, store: DevicesStore) {
        self.device = device
        self.store = store

        _editableName = State(initialValue: device.animalName)
        _editableGender = State(initialValue: device.AnimalGender)
        _editableSpecies = State(initialValue: device.AnimalSpecies)
        _weight = State(initialValue: device.animalWeight)
        _dailyGain = State(initialValue: device.animalDailyGain)
    }

    var body: some View {
        Form {
            Section {
                EditableDeviceDataControlRow(title: "Name", textValue: $editableName)

                EditableDeviceDataControlRow(
                    title: "Weight",
                    textValue: $localWeightText
                )

                EditableDeviceDataControlRow(
                    title: "Daily Gain",
                    textValue: $localDailyGainText
                )

                EditableDeviceDataControlRow(
                    title: "Gender",
                    textValue: $editableGender,
                    pickerOptions: genderOptions
                )

                EditableDeviceDataControlRow(
                    title: "Species",
                    textValue: $editableSpecies,
                    pickerOptions: typeOptions
                )
            }

            Section {
                Button("Save") {
                    saveAllChanges()
                }
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Animal Data")
        .onAppear {
            localWeightText = numberFormatter.string(from: NSNumber(value: weight)) ?? ""
            localDailyGainText = numberFormatter.string(from: NSNumber(value: dailyGain)) ?? ""
        }
    }

    private func saveAllChanges() {

        if let val = numberFormatter.number(from: localWeightText)?.doubleValue {
            weight = val
        }
        if let val = numberFormatter.number(from: localDailyGainText)?.doubleValue {
            dailyGain = val
        }

        if let index = store.devices.firstIndex(where: { $0.id == device.id }) {
            store.devices[index].animalName = editableName
            store.devices[index].animalWeight = weight
            store.devices[index].animalDailyGain = dailyGain
            store.devices[index].AnimalGender = editableGender
            store.devices[index].AnimalSpecies = editableSpecies
            store.save()
        }

        setAnimalName(editableName)
        setAnimalWeight(String(format: "%.1f", weight))
        setDailyGain(String(format: "%.1f", dailyGain))
        setAnimalGender(editableGender)
        setAnimalSpecies(editableSpecies)
    }

    private func setAnimalName(_ value: String) {
        sendCommand("/setAnimalName?value=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }

    private func setAnimalGender(_ value: String) {
        sendCommand("/setAnimalGender?value=\(value)")
    }

    private func setAnimalSpecies(_ value: String) {
        sendCommand("/setAnimalSpecies?value=\(value)")
    }

    private func setDailyGain(_ value: String) {
        sendCommand("/setDailyGain?value=\(value)")
    }

    private func setAnimalWeight(_ value: String) {
        sendCommand("/setAnimalWeight?value=\(value)")
    }

    private func sendCommand(_ path: String) {
        guard let url = URL(string: ipAddress + path) else {
            statusMessage = "Invalid URL"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if (error as NSError).code == NSURLErrorTimedOut {
                        statusMessage = "Disconnected (Timeout)"
                    } else {
                        statusMessage = "Send failed: \(error.localizedDescription)"
                    }
                } else {
                    statusMessage = "Command \(path) sent successfully"
                }
            }
        }.resume()
    }
}
