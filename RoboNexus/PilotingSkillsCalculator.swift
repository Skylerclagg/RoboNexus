//
//  PilotingSkillsCalculator.swift
//  ADC Hub
//
//  Created by Skyler Clagg on 10/30/24.
//

import SwiftUI

struct PilotingSkillsCalculator: View {
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager
    @EnvironmentObject var settings: UserSettings  // Must have `@Published var enableHaptics`
    @Environment(\.colorScheme) var colorScheme // Detect light or dark mode

    // State variables for tasks
    @State private var didTakeOff: Bool = false
    @State private var figure8Count: Int = 0
    @State private var smallHoleCount: Int = 0
    @State private var largeHoleCount: Int = 0
    @State private var keyholeCount: Int = 0

    // Landing options enumeration
    enum LandingOption: String, CaseIterable, Identifiable {
        case none = "None"
        case landOnPad = "Landing Pad"
        case landingCubeSmall = "Small Cube"
        case landingCubeLarge = "Large Cube"

        var id: String { self.rawValue }
    }

    @State private var selectedLandingOption: LandingOption = .none

    // Total score computed property
    var totalScore: Int {
        var score = 0

        // Take Off: 10 Points, Once
        if didTakeOff {
            score += 10
        }

        // Complete a Figure 8: 40 Points per completion
        score += figure8Count * 40

        // Fly Through Small Hole: 40 Points per completion
        score += smallHoleCount * 40

        // Fly Through Large Hole: 20 Points per completion
        score += largeHoleCount * 20

        // Fly Through Keyhole: 15 Points per completion
        score += keyholeCount * 15

        // Landing Options
        switch selectedLandingOption {
        case .none:
            break // No points
        case .landOnPad:
            score += 15
        case .landingCubeSmall:
            score += 40
        case .landingCubeLarge:
            score += 25
        }

        return score
    }

    // Detect the current color mode and choose text colors accordingly
    var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        Form {
            // Display total score at the top
            Section(header: Text("Total Score").foregroundStyle(textColor)) {
                Text("\(totalScore)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Tasks Section
            Section(header: Text("Tasks:").foregroundStyle(textColor)) {
                Toggle("Take Off: ", isOn: $didTakeOff)
                    .foregroundStyle(.green)
                    .toggleStyle(SwitchToggleStyle(tint: settings.buttonColor()))
                    .onChange(of: didTakeOff) { _ in
                        triggerHapticsIfEnabled()
                    }

                Stepper(value: $figure8Count, in: 0...100) {
                    HStack {
                        Text("Complete a Figure 8:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(figure8Count)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: figure8Count) { _ in
                    triggerHapticsIfEnabled()
                }

                Stepper(value: $smallHoleCount, in: 0...100) {
                    HStack {
                        Text("Fly Through Small Hole:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(smallHoleCount)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: smallHoleCount) { _ in
                    triggerHapticsIfEnabled()
                }

                Stepper(value: $largeHoleCount, in: 0...100) {
                    HStack {
                        Text("Fly Through Large Hole:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(largeHoleCount)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: largeHoleCount) { _ in
                    triggerHapticsIfEnabled()
                }

                Stepper(value: $keyholeCount, in: 0...100) {
                    HStack {
                        Text("Fly Through Keyhole:")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(keyholeCount)")
                            .foregroundStyle(textColor)
                    }
                }
                .onChange(of: keyholeCount) { _ in
                    triggerHapticsIfEnabled()
                }
            }

            // Landing Options Section
            Section(header: Text("Landing Options").foregroundStyle(textColor)) {
                Picker("Select Landing Option", selection: $selectedLandingOption) {
                    ForEach(LandingOption.allCases) { option in
                        Text(option.rawValue)
                            .tag(option)
                            .foregroundStyle(.green)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedLandingOption) { _ in
                    triggerHapticsIfEnabled()
                }
            }
        }
        .accentColor(.green) // Make all + and - buttons green
        .navigationTitle("Piloting Skills Calculator")
        .toolbar {
            // Clear Scores Button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: clearInputs) {
                    Image(systemName: "trash")
                }
                .foregroundStyle(.red)
                .accessibilityLabel("Clear Scores")
            }
        }
        .onAppear {
            navigation_bar_manager.title = "Piloting Skills Calculator"
        }
    }

    // Function to reset all inputs
    func clearInputs() {
        didTakeOff = false
        figure8Count = 0
        smallHoleCount = 0
        largeHoleCount = 0
        keyholeCount = 0
        selectedLandingOption = .none

        // HAPTICS: Trigger on clear
        triggerHapticsIfEnabled()
    }
    
    // MARK: - Haptic Trigger Helper
    private func triggerHapticsIfEnabled() {
        if settings.enableHaptics {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}

struct PilotingSkillsCalculator_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PilotingSkillsCalculator()
                .environmentObject(UserSettings())
                .environmentObject(NavigationBarManager(title: "Piloting Skills Calculator"))
        }
    }
}
