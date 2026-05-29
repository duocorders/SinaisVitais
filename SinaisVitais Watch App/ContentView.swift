import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var monitor = MonitorSinais()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                Text("Sinais Vitais")
                    .font(.headline)
                    .padding(.top)
                    .onAppear { monitor.iniciar() }

                CartaoSinal(
                    titulo: "BPM",
                    valor: monitor.bpm == 0 ? "--" : "\(Int(monitor.bpm))",
                    unidade: "bpm",
                    cor: monitor.bpm > 100 ? .red : .green
                )

                CartaoSinal(
                    titulo: "SpO2",
                    valor: monitor.spo2 == 0 ? "--" : String(format: "%.1f", monitor.spo2),
                    unidade: "%",
                    cor: monitor.spo2 < 95 && monitor.spo2 > 0 ? .red : .green
                )

                Text(monitor.status)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    monitor.ativo ? monitor.parar() : monitor.iniciar()
                }) {
                    Text(monitor.ativo ? "Parar" : "Iniciar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(monitor.ativo ? .red : .green)
                .padding(.horizontal)

            }
        }
    }
}

struct CartaoSinal: View {
    let titulo: String
    let valor: String
    let unidade: String
    let cor: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(valor)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(cor)
                    Text(unidade)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}
