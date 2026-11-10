import Foundation

var assertions = 0
func check(_ predicate: @autoclosure () throws -> Bool, _ message: String) rethrows {
    assertions += 1
    if try !predicate() { fatalError(message) }
}
func rejects(_ message: String, _ block: () throws -> Void) {
    assertions += 1
    do { try block(); fatalError(message) } catch {}
}

let read = try CherryPacket.make(op: 5, payload: CherryPacket.mainLighting)
check(Array(read.prefix(8)) == [4, 0x63, 0, 5, 8, 1, 0, 0x55], "Read request must match captured hardware packet")
let original = try LightingState(bytes: [0x12, 1, 2, 0, 0, 0, 0x3f, 0x24])
var readReply = read
readReply.replaceSubrange(8..<16, with: original.bytes)
try CherryPacket.validate(readReply, request: read)
var damaged = readReply; damaged[1] ^= 1
rejects("Must reject corrupted checksum") { try CherryPacket.validate(damaged, request: read) }
damaged = readReply; damaged[5] = 2
rejects("Must reject a response for another address") { try CherryPacket.validate(damaged, request: read) }
rejects("Must reject truncated responses") { try CherryPacket.validate(Array(readReply.prefix(63)), request: read) }
rejects("Must reject oversized requests") { _ = try CherryPacket.make(op: 6, payload: Array(repeating: 1, count: 61)) }

let desired = try original.replacing(mode: 3, brightness: 2, speed: 4, hex: "#66aaff")
check(desired.bytes == [3, 2, 4, 0, 0, 0x66, 0xaa, 0xff], "Write must preserve device flags")
let write = try CherryPacket.make(op: 6, payload: CherryPacket.mainLighting + desired.bytes)
check(write.count == 64 && write[1] == 0x7c && write[2] == 2, "Write checksum must include complete payload")
check(LightingState.rgb("$(echo test)") == nil, "Color validation must reject non-hex strings")
rejects("Must reject malformed saved backups") { _ = try JSONDecoder().decode(LightingState.self, from: Data("{\"bytes\":[3,255,4,0,0,0,0,0]}".utf8)) }
rejects("Must reject invalid brightness") { _ = try original.replacing(mode: 3, brightness: 8, speed: 2, hex: "FFFFFF") }
rejects("Must reject unknown new modes") { _ = try original.replacing(mode: 0xff, brightness: 2, speed: 2, hex: "FFFFFF") }

let existing = [KeyPair(source: KeyMapping.usageBase + 4, destination: KeyMapping.usageBase + 5)]
let remap = KeyMapping.make(existing: existing, swap: true, caps: 1)
check(remap.contains(existing[0]), "Unrelated mappings must survive updates")
check(remap.count == 6, "Swap and Caps mapping must add five mappings")
check(KeyMapping.make(existing: remap, swap: false, caps: 0) == existing, "Default must remove only managed mappings")
check(LightProfile.examples.allSatisfy(\.valid), "Built-in profiles must be valid")
try check(try CherryPacket.lightingHeader(profile: 1) == [8, 65, 0, 0], "Active profile 1 must use offset 65, not offset 1")
try check(try CherryPacket.lightingHeader(profile: 2, writing: true) == [8, 129, 0, 0x55], "Active profile 2 write must use offset 129")
let colorful = try original.replacing(mode: 0, brightness: 2, speed: 2, hex: "FF0000", rainbow: true)
check(colorful.rainbow && colorful.bytes[4] == 1 && colorful.bytes[3] == original.bytes[3], "Rainbow selection must update only its flag and preserve direction")
let single = try colorful.replacing(mode: 2, brightness: 2, speed: 2, hex: "66E3C4", rainbow: false)
check(!single.rainbow && single.bytes[4] == 0, "Switching back to single color must clear the rainbow flag")
let legacyProfile = try JSONDecoder().decode(LightProfile.self, from: Data("{\"name\":\"Legacy\",\"mode\":2,\"brightness\":2,\"speed\":2,\"hex\":\"66E3C4\"}".utf8))
check(!legacyProfile.rainbow && legacyProfile.valid, "Older profiles without the rainbow field must remain readable")
let restoredProfile = try JSONDecoder().decode(LightProfile.self, from: JSONEncoder().encode(LightProfile.examples[2]))
check(restoredProfile.rainbow && restoredProfile.mode == 0, "Rainbow profile must survive JSON roundtrip")
print("Passed \(assertions) protocol, validation and mapping checks")
