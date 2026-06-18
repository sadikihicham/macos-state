/// Historique borné (tampon circulaire) d'une métrique. Pur et testable :
/// garde les `capacity` dernières valeurs, les plus anciennes sont évincées.
public struct RingHistory: Equatable {
    public let capacity: Int
    private var buf: [Double]

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        buf = []
        buf.reserveCapacity(self.capacity)
    }

    /// Ajoute une valeur ; évince la plus ancienne au-delà de `capacity`.
    public mutating func append(_ v: Double) {
        buf.append(v)
        if buf.count > capacity { buf.removeFirst(buf.count - capacity) }
    }

    /// Valeurs du plus ancien au plus récent.
    public var values: [Double] { buf }
    public var count: Int { buf.count }
    public var last: Double? { buf.last }

    /// Normalise les valeurs dans [0...1] selon un min/max donné (pour l'affichage).
    /// Si l'étendue est nulle, renvoie 0.5 (ligne plate centrée).
    public func normalized(min lo: Double, max hi: Double) -> [Double] {
        let span = hi - lo
        guard span > 0 else { return buf.map { _ in 0.5 } }
        return buf.map { Swift.min(1, Swift.max(0, ($0 - lo) / span)) }
    }
}
