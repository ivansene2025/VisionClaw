import AVFoundation
import Foundation

class AudioManager {
  var onAudioCaptured: ((Data) -> Void)?
  /// Called when audio session is interrupted (e.g. phone call) or resumed
  var onInterruptionStateChanged: ((Bool) -> Void)?  // true = interrupted

  private let audioEngine = AVAudioEngine()
  private let playerNode = AVAudioPlayerNode()
  private var isCapturing = false
  private var isInterrupted = false
  private var interruptionObserver: Any?

  private let outputFormat: AVAudioFormat

  // Accumulate resampled PCM into ~100ms chunks before sending
  private let sendQueue = DispatchQueue(label: "audio.accumulator")
  private var accumulatedData = Data()
  private let minSendBytes = 3200  // 100ms at 16kHz mono Int16 = 1600 frames * 2 bytes

  /// Whether the audio session should mix with other apps (meeting mode background)
  private var mixWithOthers = false

  init() {
    self.outputFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: GeminiConfig.outputAudioSampleRate,
      channels: GeminiConfig.audioChannels,
      interleaved: true
    )!
  }

  func setupAudioSession(useIPhoneMode: Bool = false, backgroundMix: Bool = false) throws {
    let session = AVAudioSession.sharedInstance()
    self.mixWithOthers = backgroundMix

    // Meeting/background mode: use .default mode — no echo cancellation needed (just listening)
    // .voiceChat/.videoChat are incompatible with .mixWithOthers on iOS
    let mode: AVAudioSession.Mode
    if backgroundMix {
      mode = .default
    } else if useIPhoneMode {
      // iPhone mode: voiceChat for aggressive echo cancellation (mic + speaker co-located)
      mode = .voiceChat
    } else {
      // Glasses mode: videoChat for mild AEC (mic is on glasses, speaker is on phone)
      mode = .videoChat
    }

    var options: AVAudioSession.CategoryOptions
    if backgroundMix {
      // Meeting mode: absolute minimum — just mixWithOthers
      // Do NOT request .defaultToSpeaker or .allowBluetooth — let the active
      // call (phone/Zoom/FaceTime) keep full control of audio routing
      options = [.mixWithOthers]
    } else {
      options = [.defaultToSpeaker, .allowBluetooth]
    }

    try session.setCategory(
      .playAndRecord,
      mode: mode,
      options: options
    )
    try session.setPreferredSampleRate(GeminiConfig.inputAudioSampleRate)
    try session.setPreferredIOBufferDuration(0.064)

    if backgroundMix {
      // Meeting mode: try setActive, if it fails try progressively simpler configs.
      // Another app (phone call, Zoom) may have an exclusive audio session.
      do {
        try session.setActive(true)
        NSLog("[Audio] Meeting mode: setActive succeeded with playAndRecord")
      } catch {
        NSLog("[Audio] Meeting mode: playAndRecord setActive failed (%@), trying record-only",
              error.localizedDescription)
        // Fallback: use .record category — less demanding, more likely to coexist
        try session.setCategory(.record, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        NSLog("[Audio] Meeting mode: setActive succeeded with record-only")
      }
    } else {
      try session.setActive(true, options: [.notifyOthersOnDeactivation])
    }
    NSLog("[Audio] Session mode: %@, mixWithOthers: %@",
          backgroundMix ? "default(mix)" : useIPhoneMode ? "voiceChat" : "videoChat",
          backgroundMix ? "YES" : "NO")

    observeInterruptions()
  }

  // MARK: - Audio interruption handling

  private func observeInterruptions() {
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      self?.handleInterruption(notification)
    }
  }

  private func handleInterruption(_ notification: Notification) {
    guard let info = notification.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else { return }

    switch type {
    case .began:
      NSLog("[Audio] Interruption began (phone call, Siri, etc.)")
      isInterrupted = true
      onInterruptionStateChanged?(true)

    case .ended:
      NSLog("[Audio] Interruption ended")
      isInterrupted = false
      onInterruptionStateChanged?(false)

      // Check if we should resume
      if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        if options.contains(.shouldResume) {
          NSLog("[Audio] Resuming audio engine after interruption")
          resumeAfterInterruption()
        }
      }

    @unknown default:
      break
    }
  }

  private func resumeAfterInterruption() {
    guard isCapturing, !audioEngine.isRunning else { return }
    do {
      try AVAudioSession.sharedInstance().setActive(true)
      try audioEngine.start()
      playerNode.play()
      NSLog("[Audio] Audio engine resumed after interruption")
    } catch {
      NSLog("[Audio] Failed to resume after interruption: %@", error.localizedDescription)
    }
  }

  func startCapture() throws {
    guard !isCapturing else { return }

    // Reset audio engine to clean state before starting
    audioEngine.reset()

    audioEngine.attach(playerNode)
    let playerFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: GeminiConfig.outputAudioSampleRate,
      channels: GeminiConfig.audioChannels,
      interleaved: false
    )!
    audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playerFormat)

    let inputNode = audioEngine.inputNode
    let inputNativeFormat = inputNode.outputFormat(forBus: 0)

    NSLog("[Audio] Native input format: %@ sampleRate=%.0f channels=%d",
          inputNativeFormat.commonFormat == .pcmFormatFloat32 ? "Float32" :
          inputNativeFormat.commonFormat == .pcmFormatInt16 ? "Int16" : "Other",
          inputNativeFormat.sampleRate, inputNativeFormat.channelCount)

    // Guard against invalid audio format (happens when audio session is reconfigured
    // while another subsystem holds the audio route, e.g. DAT SDK streaming)
    if inputNativeFormat.sampleRate <= 0 || inputNativeFormat.channelCount <= 0 {
      NSLog("[Audio] Invalid input format (sampleRate=%.0f channels=%d) — retrying after session reactivation",
            inputNativeFormat.sampleRate, inputNativeFormat.channelCount)
      // Force reactivate the audio session and retry once
      let session = AVAudioSession.sharedInstance()
      try session.setActive(false, options: [.notifyOthersOnDeactivation])
      try session.setActive(true)
      audioEngine.reset()
      audioEngine.attach(playerNode)
      audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playerFormat)
      let retryFormat = audioEngine.inputNode.outputFormat(forBus: 0)
      NSLog("[Audio] Retry input format: sampleRate=%.0f channels=%d",
            retryFormat.sampleRate, retryFormat.channelCount)
      if retryFormat.sampleRate <= 0 || retryFormat.channelCount <= 0 {
        throw NSError(domain: "AudioManager", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Microphone unavailable. Close other audio apps and try again."])
      }
    }

    let finalFormat = audioEngine.inputNode.outputFormat(forBus: 0)

    // Always tap in native format (Float32) and convert to Int16 PCM manually.
    // AVAudioEngine taps don't reliably convert between sample formats inline.
    let needsResample = finalFormat.sampleRate != GeminiConfig.inputAudioSampleRate
        || finalFormat.channelCount != GeminiConfig.audioChannels

    NSLog("[Audio] Needs resample: %@", needsResample ? "YES" : "NO")

    sendQueue.async { self.accumulatedData = Data() }

    var converter: AVAudioConverter?
    if needsResample {
      let resampleFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: GeminiConfig.inputAudioSampleRate,
        channels: GeminiConfig.audioChannels,
        interleaved: false
      )!
      converter = AVAudioConverter(from: finalFormat, to: resampleFormat)
    }

    var tapCount = 0
    let tapNode = audioEngine.inputNode
    tapNode.installTap(onBus: 0, bufferSize: 4096, format: finalFormat) { [weak self] buffer, _ in
      guard let self else { return }

      tapCount += 1
      let pcmData: Data
      let rms: Float

      if let converter {
        let resampleFormat = AVAudioFormat(
          commonFormat: .pcmFormatFloat32,
          sampleRate: GeminiConfig.inputAudioSampleRate,
          channels: GeminiConfig.audioChannels,
          interleaved: false
        )!
        guard let resampled = self.convertBuffer(buffer, using: converter, targetFormat: resampleFormat) else {
          if tapCount <= 3 { NSLog("[Audio] Resample failed for tap #%d", tapCount) }
          return
        }
        pcmData = self.float32BufferToInt16Data(resampled)
        rms = self.computeRMS(resampled)
      } else {
        pcmData = self.float32BufferToInt16Data(buffer)
        rms = self.computeRMS(buffer)
      }

      // Log first 3 taps, then every ~2 seconds (every 8th tap at 4096 frames/16kHz = ~256ms each)
      // if tapCount <= 3 || tapCount % 8 == 0 {
      //   NSLog("[Audio] Tap #%d: %d frames, %d bytes, rms=%.4f",
      //         tapCount, buffer.frameLength, pcmData.count, rms)
      // }

      // Accumulate into ~100ms chunks before sending to Gemini
      self.sendQueue.async {
        self.accumulatedData.append(pcmData)
        if self.accumulatedData.count >= self.minSendBytes {
          let chunk = self.accumulatedData
          self.accumulatedData = Data()
          if tapCount <= 3 {
            NSLog("[Audio] Sending chunk: %d bytes (~%dms)",
                  chunk.count, chunk.count / 32)  // 16kHz * 2 bytes = 32 bytes/ms
          }
          self.onAudioCaptured?(chunk)
        }
      }
    }

    try audioEngine.start()
    playerNode.play()
    isCapturing = true
  }

  func playAudio(data: Data) {
    guard isCapturing, !data.isEmpty else { return }

    let playerFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: GeminiConfig.outputAudioSampleRate,
      channels: GeminiConfig.audioChannels,
      interleaved: false
    )!

    let frameCount = UInt32(data.count) / (GeminiConfig.audioBitsPerSample / 8 * GeminiConfig.audioChannels)
    guard frameCount > 0 else { return }

    guard let buffer = AVAudioPCMBuffer(pcmFormat: playerFormat, frameCapacity: frameCount) else { return }
    buffer.frameLength = frameCount

    guard let floatData = buffer.floatChannelData else { return }
    data.withUnsafeBytes { rawBuffer in
      guard let int16Ptr = rawBuffer.bindMemory(to: Int16.self).baseAddress else { return }
      for i in 0..<Int(frameCount) {
        floatData[0][i] = Float(int16Ptr[i]) / Float(Int16.max)
      }
    }

    playerNode.scheduleBuffer(buffer)
    if !playerNode.isPlaying {
      playerNode.play()
    }
  }

  func stopPlayback() {
    playerNode.stop()
    playerNode.play()
  }

  func stopCapture() {
    guard isCapturing else { return }
    isCapturing = false
    audioEngine.inputNode.removeTap(onBus: 0)
    playerNode.stop()
    audioEngine.stop()
    if audioEngine.attachedNodes.contains(playerNode) {
      audioEngine.detach(playerNode)
    }
    isInterrupted = false
    // Flush any remaining accumulated audio
    sendQueue.async {
      if !self.accumulatedData.isEmpty {
        let chunk = self.accumulatedData
        self.accumulatedData = Data()
        self.onAudioCaptured?(chunk)
      }
    }
    // Remove interruption observer
    if let observer = interruptionObserver {
      NotificationCenter.default.removeObserver(observer)
      interruptionObserver = nil
    }
  }

  // MARK: - Private helpers

  private func computeRMS(_ buffer: AVAudioPCMBuffer) -> Float {
    let frameCount = Int(buffer.frameLength)
    guard frameCount > 0, let floatData = buffer.floatChannelData else { return 0 }
    var sumSquares: Float = 0
    for i in 0..<frameCount {
      let s = floatData[0][i]
      sumSquares += s * s
    }
    return sqrt(sumSquares / Float(frameCount))
  }

  private func float32BufferToInt16Data(_ buffer: AVAudioPCMBuffer) -> Data {
    let frameCount = Int(buffer.frameLength)
    guard frameCount > 0, let floatData = buffer.floatChannelData else { return Data() }
    var int16Array = [Int16](repeating: 0, count: frameCount)
    for i in 0..<frameCount {
      let sample = max(-1.0, min(1.0, floatData[0][i]))
      int16Array[i] = Int16(sample * Float(Int16.max))
    }
    return int16Array.withUnsafeBufferPointer { ptr in
      Data(buffer: ptr)
    }
  }

  private func convertBuffer(
    _ inputBuffer: AVAudioPCMBuffer,
    using converter: AVAudioConverter,
    targetFormat: AVAudioFormat
  ) -> AVAudioPCMBuffer? {
    let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
    let outputFrameCount = UInt32(Double(inputBuffer.frameLength) * ratio)
    guard outputFrameCount > 0 else { return nil }

    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
      return nil
    }

    var error: NSError?
    var consumed = false
    converter.convert(to: outputBuffer, error: &error) { _, outStatus in
      if consumed {
        outStatus.pointee = .noDataNow
        return nil
      }
      consumed = true
      outStatus.pointee = .haveData
      return inputBuffer
    }

    if error != nil {
      return nil
    }

    return outputBuffer
  }
}
