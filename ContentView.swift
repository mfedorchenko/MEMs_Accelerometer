import Charts
import Combine
import CoreMotion
import SwiftUI

// MARK: - ViewModel
// In SwiftUI, this is all handled using an ObservableObject class with @Published properties
class MotionViewModel: ObservableObject {
    private let motionManager = CMMotionManager()
    // allSamples contains raw x, y and z values displayed in the chart
    @Published var allSamples: [SamplePoint?] = []
    // temporary buffer used to collect 4 samples before updating the chart
    private var valueSamplesTemp: [SamplePoint] = []
    
    @Published var alarm: String = ""
    @Published var isActive: Bool = false
    
    // how many measure points are shown in the array
    private let maxSamples = 600
    
    private let sampleInterval: TimeInterval = 0.05
    
    private let timeIntervalGraph: Double = -30
    private let timeIntervalStorage: Double = -300
    
    private let refreshRate = 2
    
    private var noDataTimer: Timer?
    private var offTimestamp: Date
    
    var graphSamples: [SamplePoint] {
        let thirtySecondsAgo = Date().addingTimeInterval(timeIntervalGraph)

        return allSamples.compactMap{$0}.filter {
            $0.timestamp >= thirtySecondsAgo
        }
    }

    // initialize with nil values so the chart starts compressed
    init() {

        let now = Date()
        // initializing data for later use
        self.noDataTimer = nil
        self.offTimestamp = Date()

        allSamples = (0..<maxSamples).map { index in

            let offset = Double(maxSamples - index) * sampleInterval

            return SamplePoint(
                timestamp: now.addingTimeInterval(-offset),
                xValue: nil,
                yValue: nil,
                zValue: nil
            )
        }
    }

    func start() {
        motionManager.stopAccelerometerUpdates()
        // when application starts, data should be showed again (ON/OFF Button)
        print("start")
        stopNoDataTimer()
        
        guard motionManager.isAccelerometerAvailable else {
            alarm = "Accelerometer not available"
            return
        }

        motionManager.accelerometerUpdateInterval = sampleInterval

        motionManager.startAccelerometerUpdates(to: .main) {
            [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            
            // showing data from all 3 axis on the graph
            // adding temporary array of some data points which will be sent to the graph
            self.valueSamplesTemp.append(
                SamplePoint(
                    timestamp: Date(), xValue: x, yValue: y, zValue: z
                )
            )
            // update chart every 4 samples
            if self.valueSamplesTemp.count >= refreshRate{
                self.allSamples.append(contentsOf: self.valueSamplesTemp)
                self.valueSamplesTemp.removeAll()
                
                // 5 Minutes storage
                let fiveMinutesAgo = Date().addingTimeInterval(timeIntervalStorage)
                
                self.allSamples.removeAll { point in
                    guard let point = point else {
                        return false
                    }
                    
                    return point.timestamp < fiveMinutesAgo
                }
            }
            

            
            // keep only the most recent (500) samples visible in the chart
            // if self.allSamples.count > self.maxSamples {
            //     self.allSamples.removeFirst(self.allSamples.count - self.maxSamples)
            //}
            
        }

        isActive = true
    }
    
    // generates placeholder samples while data acquisition is paused.
    // this preserves the timeline so gaps remain visible in the chart.

    
    // continuously append samples with nil values while recording is stopped.
    func startNoDataTimer() {
        offTimestamp = Date()
    }

    // stop generating placeholder samples and resume normal data collection.
    func stopNoDataTimer() {
        let now = Date()
        let offset = now.timeIntervalSince(self.offTimestamp)
        print("offset: ", offset)
        let count = Int(offset / self.sampleInterval)
        print("count: ", count)

        for index in 0..<count {
            let timestamp = self.offTimestamp.addingTimeInterval(
                Double(index) * self.sampleInterval
            )

            self.allSamples.append(
                SamplePoint(
                    timestamp: timestamp,
                    xValue: nil,
                    yValue: nil,
                    zValue: nil
                )
            )
        }
        print("Added nil sample")
    
        let thirtySecondsAgo = Date().addingTimeInterval(-30)
        self.allSamples = self.allSamples.compactMap{$0}.filter {
            $0.timestamp >= thirtySecondsAgo
        }

        noDataTimer?.invalidate()
        noDataTimer = nil
    }

    // stop accelerometer updates but continue advancing time in the chart.
    func pressOFF() {
        motionManager.stopAccelerometerUpdates()
        startNoDataTimer()
        isActive = false
    }
    
    private func average(_ arr: [Double]) -> Double {
        guard !arr.isEmpty else { return 0 }
        return arr.reduce(0, +) / Double(arr.count)
    }
}

// data type
struct SamplePoint {
    let timestamp: Date
    let xValue: Double?
    let yValue: Double?
    let zValue: Double?
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
                    ForEach(Array(viewModel.graphSamples.enumerated()), id: \.offset) { index, point in
                        if let x = point.xValue {
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Acceleration", x),
                            series: .value("Axis", "X")
                            )
                        .foregroundStyle(by: .value("Axis", "X"))
                        .interpolationMethod(.linear)
                        }
                    }
                    // Y Graph
                    ForEach(Array(viewModel.graphSamples.enumerated()), id: \.offset) { index, point in
                        if let y = point.yValue {
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Acceleration", y),
                            series: .value("Axis", "Y")
                            )
                        .foregroundStyle(by: .value("Axis", "Y"))
                        .interpolationMethod(.linear)
                        }
                    }
                    // Z Graph
                    ForEach(Array(viewModel.graphSamples.enumerated()), id: \.offset) { index, point in
                        if let z = point.zValue {
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Acceleration", z),
                            series: .value("Axis", "Z")
                            )
                        .foregroundStyle(by: .value("Axis", "Z"))
                        .interpolationMethod(.linear)
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "X": .blue,
                    "Y": .red,
                    "Z": .green
                ])
                .chartLegend(position: .bottom, alignment: .center)
                .chartXAxis(.hidden)
                .frame(height: 300)
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
                viewModel.isActive ? viewModel.pressOFF() : viewModel.start()
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
            viewModel.pressOFF()
        }
        
        
    }
}

#Preview {
    ContentView()
}
