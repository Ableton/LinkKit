// Copyright: 2021, Ableton AG, Berlin. All rights reserved.

import AVFAudio
import CoreAudio
import Foundation
import SwiftUI

class AudioEngineController: ObservableObject {

  @Published var isPlaying = false {
    didSet {
      if isPlaying {
        audioEngine?.requestTransportStart()
      } else {
        audioEngine?.requestTransportStop()
      }
    }
  }

  @Published private(set) var beatTime = 0.0

  @Published var tempo = 120.0 {
    didSet {
      audioEngine?.proposeTempo(tempo)
    }
  }

  @Published var quantum = 4.0 {
    didSet {
      audioEngine?.setQuantum(quantum)
    }
  }

  var link: ABLLinkRef? {
    audioEngine?.linkRef()
  }

  func startAudioEngine() {
    audioEngine?.start()
  }

  func stopAudioEngine() {
    audioEngine?.stop()
  }

  private let audioEngine = AudioEngine.init(tempo: 120)
  private var timer: Timer?

  init() {
    // Set ABLLink Callbacks to update `tempo` and `isPlaying` when those properties change in Link
    ABLLinkSetSessionTempoCallback(
      audioEngine?.linkRef(),
      { tempo, context in
        Unmanaged<AudioEngineController>.fromOpaque(context!).takeUnretainedValue().tempo = tempo
      },
      Unmanaged.passUnretained(self).toOpaque()
    )

    ABLLinkSetStartStopCallback(
      audioEngine?.linkRef(),
      { isPlaying, context in
        Unmanaged<AudioEngineController>.fromOpaque(context!).takeUnretainedValue().isPlaying =
          isPlaying
      },
      Unmanaged.passUnretained(self).toOpaque()
    )

    // Regularly update the beat time to be displayed in the UI
    timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
      let sessionState = ABLLinkCaptureAppSessionState(self.audioEngine?.linkRef())
      self.beatTime = ABLLinkBeatAtTime(sessionState, mach_absolute_time(), self.quantum)
    }
  }
}
