import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var monitor = MonitorSinais()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text("SINAIS VITAIS")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 6)
                .onAppear { monitor.iniciar() }

                // Grade 2x2
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    CartaoSinal(
                        icone: "heart.fill",
                        titulo: "BPM",
                        valor: monitor.bpm == 0 ? "--" : "\(Int(monitor.bpm))",
                        unidade: "bpm",
                        cor: monitor.bpm > 100 ? .red : Color(red: 0.2, green: 0.9, blue: 0.5)
                    )
                    CartaoSinal(
                        icone: "lungs.fill",
                        titulo: "SpO2",
                        valor: monitor.spo2 == 0 ? "--" : String(format: "%.1f", monitor.spo2),
                        unidade: "%",
                        cor: monitor.spo2 < 95 && monitor.spo2 > 0 ? .red : .cyan
                    )
                    CartaoSinal(
                        icone: "waveform.path.ecg",
                        titulo: "HRV",
                        valor: monitor.hrv == 0 ? "--" : String(format: "%.0f", monitor.hrv),
                        unidade: "ms",
                        cor: Color(red: 0.4, green: 0.6, blue: 1.0)
                    )
                    CartaoSinal(
                        icone: "wind",
                        titulo: "Resp.",
                        valor: monitor.freqRespiratoria == 0 ? "--" : String(format: "%.0f", monitor.freqRespiratoria),
                        unidade: "rpm",
                        cor: Color(red: 0.5, green: 0.85, blue: 1.0)
                    )
                }
                .padding(.horizontal, 8)

                // Status com indicador
                HStack(spacing: 5) {
                    Circle()
                        .fill(monitor.ativo ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(monitor.status)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal)

                Button(action: {
                    monitor.ativo ? monitor.parar() : monitor.iniciar()
                }) {
                    Label(
                        monitor.ativo ? "Parar" : "Iniciar",
                        systemImage: monitor.ativo ? "stop.fill" : "play.fill"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(monitor.ativo ? .red : Color(red: 0.2, green: 0.8, blue: 0.4))
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
        .background(Color.black)
    }
}

struct CartaoSinal: View {
    let icone: String
    let titulo: String
    let valor: String
    let unidade: String
    let cor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icone)
                    .font(.system(size: 9))
                    .foregroundStyle(cor)
                Text(titulo)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(valor)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(cor)
                    .minimumScaleFactor(0.6)
                Text(unidade)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(cor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ContentView()
}
