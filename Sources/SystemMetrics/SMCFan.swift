import Foundation
import IOKit

/// Lecture de la vitesse des ventilateurs via le SMC (System Management
/// Controller). API IOKit **publique** (IOServiceOpen/IOConnectCallStructMethod) ;
/// seule la structure SMC est non documentée. N'ouvre aucun socket → l'invariant
/// zéro-réseau tient. Best-effort : (nil, 0) si pas de ventilateur (ex. MacBook Air).
enum SMCFan {

    // Sélecteurs et commandes SMC.
    private static let kSMCHandleYPCEvent: UInt32 = 2
    private static let kSMCReadKey: UInt8 = 5
    private static let kSMCGetKeyInfo: UInt8 = 9

    /// Clé SMC sur 4 caractères → FourCharCode.
    static func fourCC(_ s: String) -> UInt32 {
        var r: UInt32 = 0
        for b in s.utf8.prefix(4) { r = (r << 8) | UInt32(b) }
        return r
    }

    // --- Layout binaire de SMCKeyData_t (doit coller au kernel) -------------
    private struct SMCVers { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0; var release: UInt16 = 0 }
    private struct SMCPLimit { var version: UInt16 = 0, length: UInt16 = 0; var cpuPLimit: UInt32 = 0, gpuPLimit: UInt32 = 0, memPLimit: UInt32 = 0 }
    // Padding explicite : sinon Swift réutilise le padding de fin pour les champs
    // suivants (offset 37 au lieu de 40), cassant l'ABI C attendu par le kernel.
    private struct SMCKeyInfo {
        var dataSize: UInt32 = 0, dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0, pad0: UInt8 = 0, pad1: UInt8 = 0, pad2: UInt8 = 0
    }
    private struct SMCParam {
        var key: UInt32 = 0
        var vers = SMCVers()
        var pLimit = SMCPLimit()
        var keyInfo = SMCKeyInfo()
        var result: UInt8 = 0, status: UInt8 = 0, data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,
                    UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8) =
                   (0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0)
    }

    /// (RPM du 1er ventilateur, nb de ventilateurs). nil si lecture impossible.
    static func read() -> (rpm: Int?, count: Int) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return (nil, 0) }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else { return (nil, 0) }
        defer { IOServiceClose(conn) }

        // Nombre de ventilateurs (clé "FNum", type ui8).
        guard let fnum = readKey(fourCC("FNum"), conn: conn), let count = fnum.value else { return (nil, 0) }
        let n = Int(count)
        guard n > 0 else { return (nil, 0) }

        // Vitesse actuelle du ventilateur 0 (clé "F0Ac").
        let rpm = readKey(fourCC("F0Ac"), conn: conn)?.value.map { Int($0.rounded()) }
        return (rpm.flatMap { $0 >= 0 && $0 < 20000 ? $0 : nil }, n)
    }

    // MARK: - Bas niveau

    private static func call(_ input: inout SMCParam, conn: io_connect_t) -> SMCParam? {
        var output = SMCParam()
        var outSize = MemoryLayout<SMCParam>.stride
        let rc = IOConnectCallStructMethod(conn, kSMCHandleYPCEvent,
                                           &input, MemoryLayout<SMCParam>.stride,
                                           &output, &outSize)
        return rc == kIOReturnSuccess ? output : nil
    }

    /// Lit une clé SMC : renvoie le type, la taille, et la valeur décodée.
    private static func readKey(_ key: UInt32, conn: io_connect_t) -> (value: Double?, type: UInt32, size: Int)? {
        var info = SMCParam(); info.key = key; info.data8 = kSMCGetKeyInfo
        guard let i = call(&info, conn: conn), i.result == 0 else { return nil }
        let size = Int(i.keyInfo.dataSize), type = i.keyInfo.dataType

        var rd = SMCParam(); rd.key = key; rd.keyInfo.dataSize = UInt32(size); rd.data8 = kSMCReadKey
        guard let r = call(&rd, conn: conn), r.result == 0 else { return nil }

        var b = r.bytes
        let arr: [UInt8] = withUnsafeBytes(of: &b) { Array($0.prefix(max(0, min(size, 32)))) }
        return (decode(type: type, bytes: arr), type, size)
    }

    /// Décode une valeur SMC selon son type (flt little-endian, fpe2 big-endian
    /// point fixe, ui8/ui16).
    private static func decode(type: UInt32, bytes: [UInt8]) -> Double? {
        if type == fourCC("flt"), bytes.count >= 4 {
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: bits))
        }
        if type == fourCC("fpe2"), bytes.count >= 2 {
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        }
        if bytes.count >= 2 { return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) }
        if bytes.count == 1 { return Double(bytes[0]) }
        return nil
    }
}
