import Foundation
import HealthKit
import Combine

class MonitorSinais: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timerPolling: Timer?

    @Published var bpm: Double = 0
    @Published var spo2: Double = 0
    @Published var hrv: Double = 0
    @Published var freqRespiratoria: Double = 0
    @Published var ativo: Bool = false
    @Published var status: String = "Iniciando..."

    private let influxURL    = "https://us-east-1-1.aws.cloud2.influxdata.com"
    private let influxToken  = "c90Mp_LTZs22bNeL-uwa1zuzmB1MZrw9Y7OZ3IJO7sAUMuFXQ3DQ5ep18kVWCS-cyBSNE1bSsEHaSHWbSDvgcg=="
    private let influxOrg    = "duocoders"
    private let influxBucket = "sinais_vitais"

    func iniciar() {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        let tiposLeitura: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
        ]
        let tiposCompartilhar: Set<HKSampleType> = [HKObjectType.workoutType()]

        healthStore.requestAuthorization(toShare: tiposCompartilhar, read: tiposLeitura) { ok, _ in
            guard ok else {
                DispatchQueue.main.async { self.status = "Permissão negada" }
                return
            }
            do {
                self.session = try HKWorkoutSession(healthStore: self.healthStore, configuration: config)
                self.builder = self.session?.associatedWorkoutBuilder()
            } catch {
                DispatchQueue.main.async { self.status = "Erro ao criar sessão" }
                return
            }

            self.session?.delegate = self
            self.builder?.delegate = self
            let dataSource = HKLiveWorkoutDataSource(
                healthStore: self.healthStore,
                workoutConfiguration: config
            )
            self.builder?.dataSource = dataSource

            let inicio = Date()
            self.session?.startActivity(with: inicio)
            self.builder?.beginCollection(withStart: inicio) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.ativo = true
                        self.status = "Monitorando..."
                        self.iniciarPolling()
                    } else {
                        self.status = "Erro: \(error?.localizedDescription ?? "desconhecido")"
                    }
                }
            }
        }
    }

    // Polling para SpO2, HRV e Respiração (não são em tempo real no Watch)
    private func iniciarPolling() {
        timerPolling = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            self.lerUltimoValor(identificador: .oxygenSaturation, unidade: HKUnit.percent()) { v in
                let pct = v * 100
                if pct > 0 { self.spo2 = pct }
            }
            self.lerUltimoValor(identificador: .heartRateVariabilitySDNN, unidade: .secondUnit(with: .milli)) { v in
                if v > 0 { self.hrv = v }
            }
            self.lerUltimoValor(identificador: .respiratoryRate, unidade: HKUnit(from: "count/min")) { v in
                if v > 0 { self.freqRespiratoria = v }
            }
        }
        timerPolling?.fire() // busca imediatamente na abertura
    }

    private func lerUltimoValor(identificador: HKQuantityTypeIdentifier,
                                 unidade: HKUnit,
                                 completion: @escaping (Double) -> Void) {
        guard let tipo = HKQuantityType.quantityType(forIdentifier: identificador) else { return }
        let query = HKSampleQuery(
            sampleType: tipo,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { _, amostras, _ in
            guard let amostra = amostras?.first as? HKQuantitySample else { return }
            let valor = amostra.quantity.doubleValue(for: unidade)
            DispatchQueue.main.async { completion(valor) }
        }
        healthStore.execute(query)
    }

    func parar() {
        timerPolling?.invalidate()
        timerPolling = nil
        session?.end()
        builder?.endCollection(withEnd: Date()) { _, _ in
            self.builder?.finishWorkout { _, _ in }
        }
        ativo = false
        status = "Monitoramento pausado"
    }

    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.status = "Erro na sessão: \(error.localizedDescription)" }
    }

    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let stats = workoutBuilder.statistics(for: quantityType) else { continue }

            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate)!:
                    let valor = stats.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
                    if valor > 0 {
                        self.bpm = valor
                        self.enviarParaInflux()
                    }
                default:
                    break
                }
            }
        }
    }

    private func enviarParaInflux() {
        let timestamp = Int(Date().timeIntervalSince1970 * 1_000_000_000)
        var campos = "bpm=\(bpm),spo2=\(spo2)"
        if hrv > 0              { campos += ",hrv=\(hrv)" }
        if freqRespiratoria > 0 { campos += ",freq_respiratoria=\(freqRespiratoria)" }
        let line = "sinais_vitais,paciente_id=WATCH,fonte=applewatch \(campos) \(timestamp)"

        guard let url = URL(string: "\(influxURL)/api/v2/write?org=\(influxOrg)&bucket=\(influxBucket)&precision=ns") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Token \(influxToken)", forHTTPHeaderField: "Authorization")
        req.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        req.httpBody = line.data(using: .utf8)

        URLSession.shared.dataTask(with: req) { data, resp, erro in
            DispatchQueue.main.async {
                if let http = resp as? HTTPURLResponse, http.statusCode == 204 {
                    self.status = "Enviado às \(self.horaAtual())"
                } else if let erro = erro {
                    self.status = "Erro de rede: \(erro.localizedDescription)"
                } else if let http = resp as? HTTPURLResponse {
                    let corpo = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    self.status = "HTTP \(http.statusCode): \(corpo.prefix(80))"
                } else {
                    self.status = "Sem resposta do servidor"
                }
            }
        }.resume()
    }

    private func horaAtual() -> String {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f.string(from: Date())
    }
}
