// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Batteria (UPower) e profilo energetico (power-profiles-daemon via UPower).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device !== null && device.isPresent && device.type === UPowerDeviceType.Battery
    // Quickshell espone la percentuale di UPower come frazione 0..1 (verificato: 100% -> 1.0)
    readonly property real percent: hasBattery ? device.percentage * 100 : 0
    readonly property bool charging: hasBattery && device.state === UPowerDeviceState.Charging
    readonly property bool full: hasBattery && device.state === UPowerDeviceState.FullyCharged
    readonly property bool onAc: !UPower.onBattery
    // in carica ferma (soglie di carica) o piena: collegato ma non in carica
    readonly property bool plugged: hasBattery && onAc && !charging
    readonly property real secondsLeft: hasBattery ? (charging ? device.timeToFull : device.timeToEmpty) : 0

    readonly property int profile: PowerProfiles.profile
    readonly property string profileName: PowerProfile.toString(profile)

    // Profili selezionabili, dal più parco al più veloce (le prestazioni solo se il demone le offre).
    readonly property var profiles: {
        var out = [{ value: PowerProfile.PowerSaver, label: "Risparmio energetico", desc: "Più autonomia, prestazioni ridotte" },
                   { value: PowerProfile.Balanced, label: "Bilanciato", desc: "Il compromesso di tutti i giorni" }];
        if (PowerProfiles.hasPerformanceProfile) out.push({ value: PowerProfile.Performance, label: "Prestazioni", desc: "Massima velocità, più consumi e calore" });
        return out;
    }
    readonly property string profileLabel: {
        for (var i = 0; i < profiles.length; i++) if (profiles[i].value === profile) return profiles[i].label;
        return profileName;
    }
    function setProfile(value) { PowerProfiles.profile = value; }

    function cycleProfile() {
        var order = [PowerProfile.PowerSaver, PowerProfile.Balanced];
        if (PowerProfiles.hasPerformanceProfile) order.push(PowerProfile.Performance);
        var i = order.indexOf(profile);
        PowerProfiles.profile = order[(i + 1) % order.length];
    }
}
