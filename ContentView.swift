import Charts
import Combine
import CoreMotion
import SwiftUI

// MARK: - ViewModel
// Entspricht in etwa deinem useState + useEffect Block im RN-Code.
// In SwiftUI läuft das Ganze über eine ObservableObject-Klasse mit @Published Properties.
class MotionViewModel: ObservableObject {
    private let motionManager = CMMotionManager()
    // This one is needed to calculate the posible earthquake, contains acceleration
    @Published var samples: [Double] = []
    // Those 3 are needed to just show data of 3 axis on the web display, contain x,y,z raw data
    @Published var xSamples: [Double] = []
    @Published var ySamples: [Double] = []
    @Published var zSamples: [Double] = []

    @Published var alarm: String = ""
    @Published var isActive: Bool = false

    // gleiche Fenstergrößen wie im RN Code
    private let staWindow = 10
    private let ltaWindow = 50
    private let maxSamples = 100

    func start() {
        guard motionManager.isAccelerometerAvailable else {
            alarm = "Accelerometer nicht verfügbar"
            return
        }

        // entspricht Accelerometer.setUpdateInterval(150) im RN Code
        motionManager.accelerometerUpdateInterval = 0.005

        motionManager.startAccelerometerUpdates(to: .main) {
            [weak self] data, error in
            guard let self = self, let data = data else { return }

            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            //
            //            // wenn Handy liegt: magnitude = 1, acceleration = |1 - 1| = 0 (Ruhezustand)
            //            // wenn Handy fällt/geschüttelt wird: acceleration weicht von 1g ab
            //            let magnitude = sqrt(x * x + y * y + z * z)
            //            let acceleration = abs(magnitude - 1)
            //
            //            // Datenmenge begrenzen, wie next.slice(-100) im RN Code
            //            self.samples.append(acceleration)
            //            if self.samples.count > self.maxSamples {
            //                self.samples.removeFirst(self.samples.count - self.maxSamples)
            //            }
            //
            //            // erst prüfen, wenn genug Daten für lta vorhanden sind
            //            if self.samples.count >= self.ltaWindow {
            //                let sta = self.average(Array(self.samples.suffix(self.staWindow)))
            //                let lta = self.average(Array(self.samples.suffix(self.ltaWindow)))
            //                let ratio = sta / lta
            //
            //                if ratio > 3 {
            //                    self.alarm = "Erdbeben erkannt"
            //                    print("Erdbeben erkannt")
            //                }
            //            }

            // Datenmenge begrenzen, wie next.slice(-100) im RN Code
            self.xSamples.append(x)
            self.ySamples.append(y)
            self.zSamples.append(z)
            if self.xSamples.count > self.maxSamples {
                self.xSamples.removeFirst(
                    self.xSamples.count - self.maxSamples
                )
            }
            if self.ySamples.count > self.maxSamples {
                self.ySamples.removeFirst(
                    self.ySamples.count - self.maxSamples
                )
            }
            if self.zSamples.count > self.maxSamples {
                self.zSamples.removeFirst(
                    self.zSamples.count - self.maxSamples
                )
            }

            // wenn Handy liegt: magnitude = 1, acceleration = |1 - 1| = 0 (Ruhezustand)
            // wenn Handy fällt/geschüttelt wird: acceleration weicht von 1g ab
            let magnitude = sqrt(x * x + y * y + z * z)
            let acceleration = abs(magnitude - 1)

            // Datenmenge begrenzen, wie next.slice(-100) im RN Code
            self.samples.append(acceleration)
            if self.samples.count > self.maxSamples {
                self.samples.removeFirst(self.samples.count - self.maxSamples)
            }

            // erst prüfen, wenn genug Daten für lta vorhanden sind
            if self.samples.count >= self.ltaWindow {
                let sta = self.average(
                    Array(self.samples.suffix(self.staWindow))
                )
                let lta = self.average(
                    Array(self.samples.suffix(self.ltaWindow))
                )
                let ratio = sta / lta

                if ratio > 3 {
                    self.alarm = "Erdbeben erkannt"
                    print("Erdbeben erkannt")
                }
            }
        }

        isActive = true
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
        isActive = false
    }

    private func average(_ arr: [Double]) -> Double {
        guard !arr.isEmpty else { return 0 }
        return arr.reduce(0, +) / Double(arr.count)
    }
}

// MARK: - View
struct ContentView: View {
    // @StateObject hält das ViewModel am Leben über den gesamten Lifecycle der View
    @StateObject private var viewModel = MotionViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                Spacer()

                // Swift Charts statt react-native-chart-kit
                Chart {
                    ForEach(Array(viewModel.xSamples.enumerated()), id: \.offset)
                    { index, value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Beschleunigung", value),
                            series: .value("Achse", "X")
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.linear)
                    }
                    ForEach(Array(viewModel.ySamples.enumerated()), id: \.offset)
                    { index, value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Beschleunigung", value),
                            series: .value("Achse", "Y")
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.linear)
                    }
                    ForEach(Array(viewModel.zSamples.enumerated()), id: \.offset)
                    { index, value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Beschleunigung", value),
                            series: .value("Achse", "Z")
                        )
                        .foregroundStyle(.green)
                        .interpolationMethod(.linear)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: 220)
                .padding()
                .overlay(
                    Rectangle().stroke(Color.black, lineWidth: 1)
                )

                Text(viewModel.alarm)
                    .padding()

                Spacer()
            }

            // entspricht dem Pressable Button im RN Code
            Button(action: {
                viewModel.isActive ? viewModel.stop() : viewModel.start()
            }) {
                Text(viewModel.isActive ? "On" : "Off")
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)
            .background(Color(red: 0.035, green: 0.545, blue: 0.839))  // #098bd6
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2.5)
            .padding(20)
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

#Preview {
    ContentView()
}
