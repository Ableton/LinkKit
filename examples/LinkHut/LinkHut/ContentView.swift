// Copyright: 2021, Ableton AG, Berlin. All rights reserved.

import SwiftUI

private let fontSize = 20.0
private let imageSize = 17.0
private let activeColor = Color(red: 1, green: 0.835, blue: 0)
private let activeDownbeatColor = Color(red: 1, green: 0.416, blue: 0)
private let countInColor = Color(red: 0.7, green: 0.7, blue: 0.7)
private let inactiveColor = Color(red: 0.25, green: 0.25, blue: 0.25)

// Wrapper to show the UIKit ABLLinkSettingsViewController in SwiftUI
struct LinkSettingsViewController: UIViewControllerRepresentable {
  var link: ABLLinkRef

  func makeUIViewController(context: Context) -> ABLLinkSettingsViewController {
    return ABLLinkSettingsViewController.instance(link)
  }

  func updateUIViewController(_ uiViewController: ABLLinkSettingsViewController, context: Context) {
  }
}

struct LinkSettingsButton: View {
  @EnvironmentObject private var engine: AudioEngineController
  @State private var showSettings = false

  var body: some View {
    Button(action: { showSettings = true }, label: { Image("Settings") })
      .buttonStyle(PlainButtonStyle())
      .sheet(
        isPresented: $showSettings,
        content: {
          NavigationView {
            if let link = engine.link {
              LinkSettingsViewController(link: link)
                .navigationBarTitle("Link Settings", displayMode: .inline)
                .navigationBarItems(
                  trailing: Button(action: { showSettings = false }) {
                    Text("Done")
                  }
                )
            }
          }
        }
      )
  }
}

struct ImageButton: View {
  var action: () -> Void
  var imageName: String
  @State private var timer: Timer?

  var body: some View {
    Button(
      action: {},
      label: {
        Image(imageName).resizable().aspectRatio(contentMode: .fit)
          .frame(width: imageSize, height: imageSize)
      }
    )
    .buttonStyle(PlainButtonStyle())
    .onLongPressGesture(
      minimumDuration: 0.1, perform: {},
      onPressingChanged: { pressed in
        if pressed {
          timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in action() }
        } else {
          timer?.invalidate()
          timer = nil
        }
      }
    )
  }
}

struct TempoControl: View {
  @EnvironmentObject private var engine: AudioEngineController

  var body: some View {
    VStack {
      Text("Tempo")
      HStack {
        ImageButton(action: { engine.tempo = max(20, engine.tempo - 1) }, imageName: "Minus")
        Text(String(format: "%.1f", engine.tempo))
        ImageButton(action: { engine.tempo = min(engine.tempo + 1, 999) }, imageName: "Plus")
      }
    }.padding().font(.system(size: fontSize))
  }
}

struct QuantumControl: View {
  @EnvironmentObject private var engine: AudioEngineController

  var body: some View {
    VStack {
      Text("Quantum")
      HStack {
        ImageButton(action: { engine.quantum = max(1, engine.quantum - 1) }, imageName: "Minus")
        Text(String(format: "%.0f", engine.quantum))
        ImageButton(action: { engine.quantum = engine.quantum + 1 }, imageName: "Plus")
      }
    }.padding().font(.system(size: fontSize))
  }
}

struct Metronome: View {
  @EnvironmentObject private var engine: AudioEngineController

  var body: some View {
    VStack {
      HStack(spacing: 1) {
        ForEach(0..<Int(engine.quantum), id: \.self) { number in
          Rectangle().fill(rectColor(number: number))
        }
        .padding(2)
      }
      .padding(2)
      HStack {
        Text(String(format: "Beat Time: %.2f", engine.beatTime)).font(.system(size: fontSize))
          .padding()
        Spacer()
      }
    }
  }

  func rectColor(number: Int) -> Color {
    let current =
      Int(engine.quantum + engine.beatTime) % Int(engine.quantum) == number
    if !engine.isPlaying || !current {
      return inactiveColor
    }
    if engine.beatTime >= 0 {
      if number == 0 {
        return activeDownbeatColor
      }
      return activeColor
    }
    return countInColor
  }
}

struct TransportButton: View {
  @EnvironmentObject private var engine: AudioEngineController

  var body: some View {
    Button(
      action: { engine.isPlaying = !engine.isPlaying },
      label: { Image(engine.isPlaying ? "Transport_Pause" : "Transport_Play") }
    )
    .buttonStyle(PlainButtonStyle())
    .padding()
  }
}

struct WideControls: View {
  var body: some View {
    HStack {
      QuantumControl()
      Spacer()
      TransportButton()
      Spacer()
      TempoControl()
    }
  }
}

struct HighControls: View {
  var body: some View {
    HStack {
      QuantumControl()
      Spacer()
      TempoControl()
    }
    Spacer()
    TransportButton()
  }
}

struct Controls: View {
  @State private var orientation = UIDevice.current.orientation

  #if targetEnvironment(macCatalyst)
    var body: some View {
      WideControls()
    }
  #else
    let orientationChanged = NotificationCenter.default.publisher(
      for: UIDevice.orientationDidChangeNotification
    )
    .makeConnectable()
    .autoconnect()

    var body: some View {
      Group {
        if orientation.isLandscape {
          WideControls()
        } else {
          HighControls()
        }
      }
      .onReceive(orientationChanged) { _ in
        self.orientation = UIDevice.current.orientation
      }
    }
  #endif
}

struct ContentView: View {
  var body: some View {
    VStack {
      HStack {
        Spacer()
        LinkSettingsButton().padding()
      }
      Spacer()
      Metronome()
      Controls()
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(AudioEngineController())
  }
}
