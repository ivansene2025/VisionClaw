import SwiftUI

// MARK: - Translation Overlay (full overlay shown during translation session)

struct TranslationOverlay: View {
  @ObservedObject var geminiVM: GeminiSessionViewModel
  private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
  }()

  private var targetLanguage: String {
    SettingsManager.shared.translationTargetLanguage
  }

  var body: some View {
    VStack(spacing: 0) {
      // Top bar: translation pill + status + output mode toggle
      HStack(spacing: 8) {
        TranslationModePill(targetLanguage: targetLanguage)
        GeminiStatusBar(geminiVM: geminiVM)
        Spacer()
        OutputModeToggle(outputMode: $geminiVM.translationOutputMode)
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)

      // Live translation scroll area
      if geminiVM.translationLines.isEmpty {
        // Empty state
        VStack(spacing: 12) {
          Spacer()
          Image(systemName: "waveform")
            .font(.system(size: 36))
            .foregroundColor(.blue.opacity(0.5))
          Text("Listening...")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.blue.opacity(0.7))
          Text("Speak in any language. Translation will appear here.")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.4))
            .multilineTextAlignment(.center)
          Spacer()
        }
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
              ForEach(geminiVM.translationLines) { line in
                HStack(alignment: .top, spacing: 8) {
                  Text(timeFormatter.string(from: line.time))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 52, alignment: .leading)
                  Text(line.text)
                    .font(.system(size: line.isTranslation ? 18 : 14,
                                  weight: line.isTranslation ? .semibold : .regular))
                    .foregroundColor(line.isTranslation ? .white : .white.opacity(0.5))
                }
                .id(line.id)
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
          }
          .onChange(of: geminiVM.translationLines.count) { _ in
            if let last = geminiVM.translationLines.last {
              withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
              }
            }
          }
        }
      }

      // Bottom: latest translation displayed large (subtitle style)
      if let lastTranslation = geminiVM.translationLines.last(where: { $0.isTranslation }) {
        VStack(spacing: 4) {
          Text(lastTranslation.text)
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
        .padding(.horizontal, 16)
      }

      Spacer(minLength: 0)
    }
    .padding(.bottom, 80)
  }
}

// MARK: - Translation Mode Pill (blue pulsing indicator)

struct TranslationModePill: View {
  let targetLanguage: String
  @State private var pulsing = false

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(Color.blue)
        .frame(width: 8, height: 8)
        .scaleEffect(pulsing ? 1.3 : 1.0)
        .animation(
          .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
          value: pulsing
        )
      Image(systemName: "globe")
        .font(.system(size: 10))
        .foregroundColor(.blue)
      Text("Translating")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.blue)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.blue.opacity(0.15))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.blue.opacity(0.4), lineWidth: 1)
    )
    .onAppear { pulsing = true }
  }
}

// MARK: - Output Mode Toggle (cycle Text/Audio/Both)

struct OutputModeToggle: View {
  @Binding var outputMode: TranslationOutputMode

  private var icon: String {
    switch outputMode {
    case .textOnly:  return "text.bubble"
    case .audioOnly: return "speaker.wave.2"
    case .both:      return "text.bubble.fill"
    }
  }

  var body: some View {
    Button(action: {
      // Cycle through modes
      switch outputMode {
      case .both:      outputMode = .textOnly
      case .textOnly:  outputMode = .audioOnly
      case .audioOnly: outputMode = .both
      }
      // Persist
      SettingsManager.shared.translationOutputMode = outputMode.rawValue
    }) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 11))
        Text(outputMode.label)
          .font(.system(size: 11, weight: .medium))
      }
      .foregroundColor(.blue)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.blue.opacity(0.15))
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.blue.opacity(0.3), lineWidth: 1)
      )
    }
  }
}
