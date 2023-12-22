
import Glibc
import Foundation

struct SystemdHelpers {
    static let isSystemdService: Bool = getIsSystemdService()

    private static func getIsSystemdService() -> Bool {
        let pid = Glibc.getppid()
        do {
            let name = try String(contentsOfFile: "/proc/\(pid)/comm")
                                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return name == "systemd"
        } catch {
            print("Unable to determine if running systemd: \(error)")
        }
        return false
    }
}
