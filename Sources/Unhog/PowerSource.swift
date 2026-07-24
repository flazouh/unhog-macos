import Foundation
import IOKit.ps

enum PowerSource {
    static var isUsingBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let value = IOPSGetProvidingPowerSourceType(info)?
                .takeUnretainedValue() as String? else {
            return false
        }
        return value == kIOPSBatteryPowerValue
    }
}
