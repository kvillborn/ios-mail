//
//  ServicePlanDetails+Extensions.swift
//  ProtonCore_PaymentsUI - Created on 01/06/2021.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ProtonCore_Payments
import ProtonCore_CoreTranslation

extension Plan {

    public var titleDescription: String {
        return title
    }
    
    var storageformatter: StorageFormatter {
        return StorageFormatter()
    }

    var XGBStorageDescription: String {
        String(format: CoreString._pu_plan_details_storage,
               storageformatter.format(value: maxSpace))
    }

    var XGBStoragePerUserDescription: String {
        return String(format: CoreString._pu_plan_details_storage_per_user,
                      storageformatter.format(value: maxSpace))
    }

    var YAddressesDescription: String {
        String(format: CoreString._pu_plan_details_n_addresses, maxAddresses)
    }

    var YAddressesPerUserDescription: String {
        String(format: CoreString._pu_plan_details_n_addresses_per_user, maxAddresses)
    }

    var ZCalendarsDescription: String? {
        guard let maxCalendars = maxCalendars else { return nil }
        return String(format: CoreString._pu_plan_details_n_calendars, maxCalendars)
    }

    var ZCalendarsPerUserDescription: String? {
        guard let maxCalendars = maxCalendars else { return nil }
        return String(format: CoreString._pu_plan_details_n_calendars_per_user, maxCalendars)
    }

    var UConnectionsDescription: String {
        String(format: CoreString._pu_plan_details_n_connections, maxVPN)
    }
    
    var UVPNConnectionsDescription: String {
        String(format: CoreString._pu_plan_details_n_vpn_connections, maxVPN)
    }

    var UHighSpeedVPNConnectionsDescription: String {
        String(format: CoreString._pu_plan_details_n_high_speed_connections, maxVPN)
    }

    var UHighSpeedVPNConnectionsPerUserDescription: String {
        String(format: CoreString._pu_plan_details_n_high_speed_connections_per_user, maxVPN)
    }

    var VCustomDomainDescription: String {
        String(format: CoreString._pu_plan_details_n_custom_domains, maxDomains)
    }

    var WUsersDescription: String {
        String(format: CoreString._pu_plan_details_n_users, maxMembers)
    }

    var YAddressesAndZCalendars: String {
        guard let ZCalendarsDescription = ZCalendarsDescription else { return YAddressesDescription }
        if maxAddresses == maxCalendars {
            return String(format: CoreString._pu_plan_details_n_addresses_and_calendars, maxAddresses)
        } else {
            return String(format: CoreString._pu_plan_details_n_uneven_amounts_of_addresses_and_calendars,
                          YAddressesDescription, ZCalendarsDescription)
        }
    }
    
    var freeLabelsDescription: String {
        return String(format: CoreString._pu_plan_details_n_folders, 3)
    }
    
    var plusLabelsDescription: String {
        return String(format: CoreString._pu_plan_details_n_folders, 200)
    }
    
    var vpnFreeSppedDescription: String {
        return CoreString._pu_plan_details_vpn_free_speed
    }

    var vpnFreeCountriesDescription: String {
        return String(format: CoreString._pu_plan_details_countries, 3)
    }
    
    var vpnPaidCountriesDescription: String {
        return String(format: CoreString._pu_plan_details_countries, 63)
    }
    
    var customEmailDescription: String {
        return CoreString._pu_plan_details_custom_email
    }
    
    var prioritySupportDescription: String {
        return CoreString._pu_plan_details_priority_support
    }
    
    var highSpeedDescription: String {
        CoreString._pu_plan_details_high_speed
    }

    var highestSpeedDescription: String {
        CoreString._pu_plan_details_highest_speed
    }

    var multiUserSupportDescription: String {
        CoreString._pu_plan_details_multi_user_support
    }
    
    var adblockerDescription: String {
        CoreString._pu_plan_details_adblocker
    }
    
    var streamingServiceDescription: String {
        CoreString._pu_plan_details_streaming_service
    }
    
    var cycleDescription: String? {
        guard let cycle = cycle, cycle > 0 else { return nil }
        let dateComponents = DateComponents(month: cycle)
        let cycleString: String?
        if cycle % 12 == 0 {
            cycleString = yearsFormatter.string(from: dateComponents)
        } else {
            cycleString = monthsFormatter.string(from: dateComponents)
        }
        guard let cycleString = cycleString else { return nil }
        return String(format: CoreString._pu_plan_details_price_time_period_no_unit, cycleString)
    }
}

private let monthsFormatter: DateComponentsFormatter = createSingleUnitFormatter(unit: .month)

private let yearsFormatter: DateComponentsFormatter = createSingleUnitFormatter(unit: .year)

private func createSingleUnitFormatter(unit: NSCalendar.Unit) -> DateComponentsFormatter {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = unit
    formatter.allowsFractionalUnits = false
    formatter.collapsesLargestUnit = true
    formatter.maximumUnitCount = 1
    formatter.zeroFormattingBehavior = .dropAll
    formatter.unitsStyle = .full
    return formatter
}
