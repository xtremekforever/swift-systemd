// SPDX-License-Identifier: MIT

#if os(Linux)
    import CSystemd
    import Dispatch
    import Glibc
    import SystemPackage

    #if canImport(FoundationEssentials)
        import FoundationEssentials
    #else
        import Foundation
    #endif

    final class SystemdBusSlot: Hashable {
        private let _s: OpaquePointer

        init(consuming s: OpaquePointer) {
            _s = s
        }

        init(borrowing s: OpaquePointer) {
            sd_bus_slot_ref(s)
            _s = s
        }

        deinit {
            sd_bus_slot_unref(_s)
        }

        public func hash(into hasher: inout Hasher) {
            ObjectIdentifier(self).hash(into: &hasher)
        }

        static func == (_ lhs: SystemdBusSlot, _ rhs: SystemdBusSlot) -> Bool {
            lhs === rhs
        }
    }
#endif
