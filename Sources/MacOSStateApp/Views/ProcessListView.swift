import SwiftUI
import SystemMetrics

/// Liste des process les plus gourmands + action "Tuer" (avec garde KillGuard).
struct ProcessListView: View {
    let processes: [ProcSample]
    let decide: (ProcSample) -> KillDecision
    let onKill: (ProcSample) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("PROCESSUS (TOP CPU)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            ForEach(processes) { p in row(p) }
        }
    }

    private func row(_ p: ProcSample) -> some View {
        let decision = decide(p)
        return HStack(spacing: 6) {
            icon(for: p.pid)
            Text(p.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1).truncationMode(.middle)
                .frame(width: 78, alignment: .leading)
            Text(String(format: "%.0f%%", p.cpuPercent))
                .font(.system(size: 10, design: .rounded)).monospacedDigit()
                .foregroundStyle(loadColor(min(1, p.cpuPercent / 100)))
                .frame(width: 34, alignment: .trailing)
            Text(Metrics.formatBytes(Double(p.memBytes)))
                .font(.system(size: 10, design: .rounded)).monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            Spacer(minLength: 2)
            killButton(p, decision: decision)
        }
    }

    private func killButton(_ p: ProcSample, decision: KillDecision) -> some View {
        Button { onKill(p) } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(decision.isDenied ? .gray.opacity(0.35)
                                 : (isWarning(decision) ? .orange : .red))
        }
        .buttonStyle(.plain)
        .disabled(decision.isDenied)
        .help(helpText(decision))
    }

    private func icon(for pid: pid_t) -> some View {
        Group {
            if let img = NSRunningApplication(processIdentifier: pid)?.icon {
                Image(nsImage: img).resizable().frame(width: 13, height: 13)
            } else {
                Image(systemName: "terminal")
                    .font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 13)
            }
        }
    }

    private func isWarning(_ d: KillDecision) -> Bool {
        if case .allowedWithWarning = d { return true }; return false
    }

    private func helpText(_ d: KillDecision) -> String {
        switch d {
        case .allowed: return "Tuer ce process"
        case .allowedWithWarning(let w): return w
        case .denied(let r): return r
        }
    }
}
