import Charts
import Combine
import CoreMotion
import SwiftUI

// MARK: - ViewModel
// In SwiftUI, this is all handled using an ObservableObject class with @Published properties
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

    private let staWindow = 10
    private let ltaWindow = 50
    // how many measure points are shown in the array
    private let maxSamples = 500

    func start() {
        guard motionManager.isAccelerometerAvailable else {
            alarm = "Accelerometer nicht verfügbar"
            return
        }

        motionManager.accelerometerUpdateInterval = 0.05

        motionManager.startAccelerometerUpdates(to: .main) {
            [weak self] data, error in
            guard let self = self, let data = data else { return }

            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            // this code is for showing only the acceleration on the graph, not all 3 axis separated
            //
            //            // when mobile is lying: magnitude = 1, acceleration = |1 - 1| = 0 (Passive state)
            //            // if the phone is dropped or shaken: the acceleration deviates from 1g
            //            let magnitude = sqrt(x * x + y * y + z * z)
            //            let acceleration = abs(magnitude - 1)
            //
            //            // Limit the amount of data
            //            self.samples.append(acceleration)
            //            if self.samples.count > self.maxSamples {
            //                self.samples.removeFirst(self.samples.count - self.maxSamples)
            //            }
            //
            //            // check first, if there're enough data for lta
            //            if self.samples.count >= self.ltaWindow {
            //                let sta = self.average(Array(self.samples.suffix(self.staWindow)))
            //                let lta = self.average(Array(self.samples.suffix(self.ltaWindow)))
            //                let ratio = sta / lta
            //
            //                if ratio > 3 {
            //                    self.alarm = "Earthquake detected"
            //                    print("Earthquake detected")
            //                }
            //            }

            // showing data from all 3 axis on the graph
            self.xSamples.append(x)
            self.ySamples.append(y)
            self.zSamples.append(z)
            
            // Limit the amount of data
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

            // when mobile is lying: magnitude = 1, acceleration = |1 - 1| = 0 (Passive state)
            // if the phone is dropped or shaken: the acceleration deviates from 1g
            let magnitude = sqrt(x * x + y * y + z * z)
            let acceleration = abs(magnitude - 1)

            // Limit the amount of data
            self.samples.append(acceleration)
            if self.samples.count > self.maxSamples {
                self.samples.removeFirst(self.samples.count - self.maxSamples)
            }

            // check first, if there're enough data for lta
            if self.samples.count >= self.ltaWindow {
                let sta = self.average(
                    Array(self.samples.suffix(self.staWindow))
                )
                let lta = self.average(
                    Array(self.samples.suffix(self.ltaWindow))
                )
                let ratio = sta / lta

                if ratio > 3 {
                    self.alarm = "Earthquake detected"
                    print("Earthquake detected")
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
    // @StateObject keeps the ViewModel alive throughout the entire lifecycle of the View
    @StateObject private var viewModel = MotionViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                Spacer()
                Chart {
                    // X Graph
                    ForEach(Array(viewModel.xSamples.enumerated()), id: \.offset)
                    { index, value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Beschleunigung", value),
                            series: .value("Achse", "X")
                        )
                        .foregroundStyle(by: .value("Achse", "X"))
                        .interpolationMethod(.linear)
                    }
                    // Y Graph
                    ForEach(Array(viewModel.ySamples.enumerated()), id: \.offset)
                    { index, value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Beschleunigung", value),
                            series: .value("Achse", "Y")
                        )
                        .foregroundStyle(by: .value("Achse", "Y"))
                        .interpolationMethod(.linear)
                    }
                    // Z Graph
                    ForEach(Array(viewModel.zSamples.enumerated()), id: \.offset)
                    { index, value in
                        LineMark(
                            x: .value("Index", index),
                            y: .value("Beschleunigung", value),
                            series: .value("Achse", "Z")
                        )
                        .foregroundStyle(by: .value("Achse", "Z"))
                        .interpolationMethod(.linear)
                    }
                }
                .chartForegroundStyleScale([
                    "X": .blue,
                    "Y": .red,
                    "Z": .green
                ])
                .chartLegend(position: .bottom, alignment: .center)
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
            // button to toggle the projecting of data on the graph
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
