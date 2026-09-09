#!/usr/bin/env python3
"""Merge the V2 telemetry / panel-border block into rise/Theme.qml.

Idempotent: every edit is guarded on a marker string, so a second run is a
no-op. Refuses to write unless a string-aware brace/paren balance check passes
on the result.

Usage: port-v2-telemetry.py [path/to/Theme.qml]
"""
import re
import shutil
import sys
from pathlib import Path

TARGET = Path(sys.argv[1] if len(sys.argv) > 1
              else "config/quickshell/rise/Theme.qml")

# ── edits: (guard, anchor, position, payload) ────────────────────────────────
# guard  : if present in the file, the edit is already applied
# anchor : exact unique text to attach to
# position: "after" | "before" | "replace"

PANEL_GEOMETRY = '''
    readonly property int v2ActionIconCellWidth: 22
    readonly property int v2IconGroupPadding: 5
    property real v2BarBorderMix: 0.22
    readonly property color v2BarBorder: Qt.rgba(
        paper.r * (1 - v2BarBorderMix) + ink.r * v2BarBorderMix,
        paper.g * (1 - v2BarBorderMix) + ink.g * v2BarBorderMix,
        paper.b * (1 - v2BarBorderMix) + ink.b * v2BarBorderMix, 1.0)
    readonly property color v2BarShadow: Qt.rgba(0, 0, 0, 0.46)
    property bool panelTooltipBorderEnabled: true
    readonly property int   panelRadius:       6
    readonly property int   panelButtonRadius: 6
    readonly property color panelBorder:       v2BarBorder
    readonly property int   panelBorderW:      1
    readonly property color panelOuterBorderColor: panelTooltipBorderEnabled
        ? panelBorder : Qt.rgba(0, 0, 0, 0)
    readonly property int panelOuterBorderW: panelTooltipBorderEnabled ? panelBorderW : 0
    property real panelInsetX: 0
    function setPanelInsetX(x) {
        if (isFinite(x) && x > 0) panelInsetX = x
    }
'''

VISIBILITY = '''    property bool gpuVisible: false
    onGpuVisibleChanged: popupOpened("gpuVisible")
    property bool thermalVisible: false
    onThermalVisibleChanged: popupOpened("thermalVisible")
    property bool storageVisible: false
    onStorageVisibleChanged: popupOpened("storageVisible")
'''

MODULE_FLAGS = '''    property bool modCpuTemperature: true
    property bool modStorage:    true
'''

CPU_PROPS = '''    property int systemCpuUserPercent: 0
    property int systemCpuSystemPercent: 0
    property int systemCpuIoWaitPercent: 0
    property real _systemCpuPrevUser: -1
    property real _systemCpuPrevSystem: -1
    property real _systemCpuPrevIoWait: -1
    property string cpuModelName: ""
    property int cpuCoreCount: 0
    property int cpuThreadCount: 0
    property int cpuClockMHz: 0
    property int cpuMaxClockMHz: 0
    property string cpuEnergyPreference: ""
    property string cpuScalingGovernor: ""
    property int cpuThrottleCount: 0
    property real systemLoad1: 0
    property real systemLoad5: 0
    property real systemLoad15: 0
    property string kernelRelease: ""
    property var cpuTopProcesses: []
'''

MEM_PROPS = '''    property string memoryType: ""
    property int memorySpeedMTs: 0
'''

TELEMETRY_PROPS = '''
    property string gpuBackend: ""
    property string gpuName: ""
    property string gpuDriverVersion: ""
    property int gpuPercent: 0
    property int gpuTemperatureC: 0
    property int gpuMemoryUsedMiB: 0
    property int gpuMemoryTotalMiB: 0
    property int gpuClockMHz: 0
    property real gpuPowerW: 0
    property real gpuPowerLimitW: 0
    property string gpuPerformanceState: ""
    property int gpuFanPercent: 0
    readonly property bool gpuAvailable: gpuBackend !== ""

    property int cpuTemperatureC: 0
    property int cpuCoreMaxTemperatureC: 0
    property int cpuTemperatureMaxC: 0
    property int cpuTemperatureCriticalC: 0
    property int nvmeTemperatureC: 0
    property int nvmeTemperatureMaxC: 0
    property int nvmeTemperatureCriticalC: 0
    property int memoryTemperatureC: 0
    readonly property bool cpuTemperatureAvailable: cpuTemperatureC > 0

    property string barTemperatureSource: "cpu"
    readonly property int barTemperatureC: barTemperatureSource === "core" ? cpuCoreMaxTemperatureC
        : barTemperatureSource === "gpu" ? gpuTemperatureC
        : barTemperatureSource === "nvme" ? nvmeTemperatureC
        : barTemperatureSource === "memory" ? memoryTemperatureC
        : cpuTemperatureC
    readonly property bool barTemperatureAvailable: barTemperatureC > 0

    function barTemperatureSourceValid(source) {
        return source === "cpu" || source === "core" || source === "gpu"
            || source === "nvme" || source === "memory"
    }
    function barTemperatureSourceLabel(source) {
        if (source === "core") return "Hottest CPU core"
        if (source === "gpu") return "GPU"
        if (source === "nvme") return "NVMe"
        if (source === "memory") return "Memory"
        return "CPU package"
    }
    function barTemperatureSourceAvailable(source) {
        if (source === "core") return cpuCoreMaxTemperatureC > 0
        if (source === "gpu") return gpuTemperatureC > 0
        if (source === "nvme") return nvmeTemperatureC > 0
        if (source === "memory") return memoryTemperatureC > 0
        return cpuTemperatureC > 0
    }

    property int storagePercent: 0
    property real storageUsedBytes: 0
    property real storageTotalBytes: 0
    property bool storageAvailable: false
    readonly property real storageUsedGiB: storageUsedBytes / 1073741824
    readonly property real storageTotalGiB: storageTotalBytes / 1073741824
    property var storageDrives: []
    property bool storageInventoryAvailable: false
'''

# Existing body, replaced wholesale by the merged version (V2's user/system/
# iowait split + this fork's systemCpuHistory ring buffer).
OLD_PARSE_CPU = '''    function parseSystemCpu(text) {
        var lines = String(text || "").split("\\n")
        if (lines.length === 0 || lines[0].indexOf("cpu ") !== 0) return
        var parts = lines[0].trim().split(/\\s+/)
        if (parts.length < 8) return

        var idle = parseFloat(parts[4]) + parseFloat(parts[5])
        var total = 0
        for (var i = 1; i < parts.length; i++) {
            var v = parseFloat(parts[i])
            if (!isNaN(v)) total += v
        }
        if (isNaN(idle) || isNaN(total) || total <= 0) return

        if (_systemCpuPrevTotal >= 0 && total > _systemCpuPrevTotal) {
            var totalDelta = total - _systemCpuPrevTotal
            var idleDelta = idle - _systemCpuPrevIdle
            var busy = totalDelta > 0 ? Math.round((totalDelta - idleDelta) / totalDelta * 100) : 0
            systemCpuPercent = Math.max(0, Math.min(100, busy))

            var h = systemCpuHistory.slice()
            h.push(systemCpuPercent / 100)
            if (h.length > systemCpuMaxSamples) h.shift()
            systemCpuHistory = h
        }

        _systemCpuPrevIdle = idle
        _systemCpuPrevTotal = total
    }'''

NEW_PARSE_CPU = '''    function parseSystemCpu(text) {
        var lines = String(text || "").split("\\n")
        if (lines.length === 0 || lines[0].indexOf("cpu ") !== 0) return
        var parts = lines[0].trim().split(/\\s+/)
        if (parts.length < 8) return

        function field(index) {
            var value = parseFloat(parts[index])
            return isNaN(value) ? 0 : value
        }
        var user = field(1) + field(2)
        var system = field(3) + field(6) + field(7) + field(8)
        var ioWait = field(5)
        var idle = field(4) + ioWait
        var total = 0
        for (var i = 1; i < parts.length; i++) {
            var v = parseFloat(parts[i])
            if (!isNaN(v)) total += v
        }
        if (isNaN(idle) || isNaN(total) || total <= 0) return

        if (_systemCpuPrevTotal >= 0 && total > _systemCpuPrevTotal) {
            var totalDelta = total - _systemCpuPrevTotal
            var idleDelta = idle - _systemCpuPrevIdle
            var busy = totalDelta > 0 ? Math.round((totalDelta - idleDelta) / totalDelta * 100) : 0
            systemCpuPercent = Math.max(0, Math.min(100, busy))
            systemCpuUserPercent = Math.max(0, Math.min(100,
                Math.round((user - _systemCpuPrevUser) / totalDelta * 100)))
            systemCpuSystemPercent = Math.max(0, Math.min(100,
                Math.round((system - _systemCpuPrevSystem) / totalDelta * 100)))
            systemCpuIoWaitPercent = Math.max(0, Math.min(100,
                Math.round((ioWait - _systemCpuPrevIoWait) / totalDelta * 100)))

            var h = systemCpuHistory.slice()
            h.push(systemCpuPercent / 100)
            if (h.length > systemCpuMaxSamples) h.shift()
            systemCpuHistory = h
        }

        _systemCpuPrevIdle = idle
        _systemCpuPrevTotal = total
        _systemCpuPrevUser = user
        _systemCpuPrevSystem = system
        _systemCpuPrevIoWait = ioWait
    }'''

NEW_FUNCS = r"""
    function parseCpuInfo(text) {
        var blocks = String(text || "").trim().split(/\n\s*\n/)
        var model = ""
        var threads = 0
        var cores = {}
        var fallbackCores = 0

        for (var i = 0; i < blocks.length; i++) {
            var lines = blocks[i].split("\n")
            var physical = "0"
            var core = ""
            var processorFound = false
            for (var j = 0; j < lines.length; j++) {
                var splitAt = lines[j].indexOf(":")
                if (splitAt < 0) continue
                var key = lines[j].slice(0, splitAt).trim()
                var value = lines[j].slice(splitAt + 1).trim()
                if (key === "processor") processorFound = true
                else if ((key === "model name" || key === "Hardware") && model === "") model = value
                else if (key === "physical id") physical = value
                else if (key === "core id") core = value
                else if (key === "cpu cores" && fallbackCores === 0) fallbackCores = parseInt(value) || 0
            }
            if (processorFound) threads++
            if (core !== "") cores[physical + ":" + core] = true
        }

        cpuModelName = model.replace(/\(R\)|\(TM\)/g, "")
            .replace(/\s+CPU\s+@\s+.*$/, "").replace(/\s+/g, " ").trim()
        cpuThreadCount = threads
        var coreKeys = Object.keys(cores)
        cpuCoreCount = coreKeys.length > 0 ? coreKeys.length : fallbackCores
    }

    function parseSystemLoad(text) {
        var fields = String(text || "").trim().split(/\s+/)
        if (fields.length < 3) return
        systemLoad1 = parseFloat(fields[0]) || 0
        systemLoad5 = parseFloat(fields[1]) || 0
        systemLoad15 = parseFloat(fields[2]) || 0
    }

    function parseCpuDetail(text) {
        var fields = String(text || "").trim().split("|")
        if (fields.length < 5) return
        cpuClockMHz = Math.max(0, parseInt(fields[0]) || 0)
        cpuMaxClockMHz = Math.max(0, parseInt(fields[1]) || 0)
        cpuEnergyPreference = String(fields[2] || "").trim()
        cpuScalingGovernor = String(fields[3] || "").trim()
        cpuThrottleCount = Math.max(0, parseInt(fields[4]) || 0)
    }

    function parseCpuTopProcesses(text) {
        var lines = String(text || "").split("\n")
        var processes = []
        for (var i = 0; i < lines.length && processes.length < 3; i++) {
            var match = lines[i].trim().match(/^(.*\S)\s+([0-9]+(?:[.,][0-9]+)?)$/)
            if (!match || match[1] === "ps") continue
            var percent = parseFloat(match[2].replace(",", "."))
            if (isNaN(percent)) continue
            processes.push({ name: match[1], percent: percent })
        }
        cpuTopProcesses = processes
    }

    function parseMemoryHardware(text) {
        var raw = String(text || "")
        var matcher = /type:\s*(DDR[0-9]+)\b[^\n]*\bspeed:\s*([0-9]+)\s*MT\/s/gi
        var match
        var type = ""
        var speed = 0
        while ((match = matcher.exec(raw)) !== null) {
            var candidate = parseInt(match[2]) || 0
            if (type === "") type = match[1].toUpperCase()
            if (candidate > 0 && (speed === 0 || candidate < speed)) speed = candidate
        }
        memoryType = type
        memorySpeedMTs = speed
    }

    function parseGpuTelemetry(text) {
        var fields = String(text || "").trim().split("|")
        if (fields.length < 12 || fields[0] === "none") {
            gpuBackend = ""
            gpuName = ""
            gpuDriverVersion = ""
            gpuPercent = 0
            gpuTemperatureC = 0
            gpuMemoryUsedMiB = 0
            gpuMemoryTotalMiB = 0
            gpuClockMHz = 0
            gpuPowerW = 0
            gpuPowerLimitW = 0
            gpuPerformanceState = ""
            gpuFanPercent = 0
            return
        }

        function clean(value) { return String(value || "").trim() }
        function number(value) {
            var parsed = parseFloat(clean(value))
            return isNaN(parsed) ? 0 : parsed
        }

        gpuBackend = clean(fields[0])
        gpuName = clean(fields[1])
        gpuDriverVersion = clean(fields[2])
        gpuPercent = Math.max(0, Math.min(100, Math.round(number(fields[3]))))
        gpuTemperatureC = Math.max(0, Math.round(number(fields[4])))
        gpuMemoryUsedMiB = Math.max(0, Math.round(number(fields[5])))
        gpuMemoryTotalMiB = Math.max(0, Math.round(number(fields[6])))
        gpuClockMHz = Math.max(0, Math.round(number(fields[7])))
        gpuPowerW = Math.max(0, number(fields[8]))
        gpuPowerLimitW = Math.max(0, number(fields[9]))
        gpuPerformanceState = clean(fields[10])
        gpuFanPercent = Math.max(0, Math.min(100, Math.round(number(fields[11]))))
    }

    function parseThermalTelemetry(text) {
        var fields = String(text || "").trim().split("|")
        function thermal(index) {
            var value = parseInt(fields[index])
            return isNaN(value) ? 0 : Math.max(0, Math.min(150, value))
        }
        cpuTemperatureC = thermal(0)
        cpuCoreMaxTemperatureC = thermal(1)
        cpuTemperatureMaxC = thermal(2)
        cpuTemperatureCriticalC = thermal(3)
        nvmeTemperatureC = thermal(4)
        nvmeTemperatureMaxC = thermal(5)
        nvmeTemperatureCriticalC = thermal(6)
        memoryTemperatureC = thermal(7)
    }

    function parseStorageInventory(text) {
        var parsed
        try {
            parsed = JSON.parse(String(text || ""))
        } catch (error) {
            storageInventoryAvailable = false
            storageDrives = []
            return
        }

        var devices = parsed && parsed.blockdevices ? parsed.blockdevices : []
        var drives = []

        function textValue(value) {
            return value === null || value === undefined ? "" : String(value).trim()
        }
        function collectVolumes(node, target) {
            var fs = textValue(node.fstype)
            var mounts = node.mountpoints || []
            var mountedAt = ""
            for (var m = 0; m < mounts.length; m++) {
                var candidate = textValue(mounts[m])
                if (candidate !== "" && candidate !== "[SWAP]") {
                    mountedAt = candidate
                    break
                }
            }
            if (fs !== "") {
                var pct = parseInt(textValue(node["fsuse%"]).replace("%", ""))
                var freeText = textValue(node.fsavail)
                var freeBytes = freeText === "" ? -1 : Number(freeText)
                var usedText = textValue(node.fsused)
                var usedBytes = usedText === "" ? -1 : Number(usedText)
                target.push({
                    fs: fs,
                    mount: mountedAt,
                    percent: isNaN(pct) ? -1 : Math.max(0, Math.min(100, pct)),
                    freeBytes: isNaN(freeBytes) ? -1 : Math.max(0, freeBytes),
                    usedBytes: isNaN(usedBytes) ? -1 : Math.max(0, usedBytes)
                })
            }
            var children = node.children || []
            for (var c = 0; c < children.length; c++) collectVolumes(children[c], target)
        }

        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            var name = textValue(device.name)
            if (device.type !== "disk" || name.indexOf("loop") === 0
                    || name.indexOf("ram") === 0 || name.indexOf("zram") === 0)
                continue

            var volumes = []
            collectVolumes(device, volumes)
            var fileSystems = []
            var mountedAt = ""
            var usage = -1
            var freeBytes = -1
            var usedBytes = -1
            for (var v = 0; v < volumes.length; v++) {
                if (fileSystems.indexOf(volumes[v].fs) < 0) fileSystems.push(volumes[v].fs)
                if (mountedAt === "" && volumes[v].mount !== "") {
                    mountedAt = volumes[v].mount
                    usage = volumes[v].percent
                    freeBytes = volumes[v].freeBytes
                    usedBytes = volumes[v].usedBytes
                }
            }

            var transport = textValue(device.tran).toUpperCase()
            var removable = device.rm === true || device.hotplug === true || transport === "USB"
            var driveType = transport === "NVME" ? "nvme"
                : device.rota === true ? "hdd"
                : "ssd"
            var media = removable ? "USB DRIVE"
                : transport === "NVME" ? "NVME SSD"
                : device.rota === true ? (transport !== "" ? transport + " HDD" : "HDD")
                : (transport !== "" ? transport + " SSD" : "SSD")
            var state = mountedAt !== "" ? mountedAt
                : (fileSystems.length > 0 ? "Not mounted" : "No filesystem")

            drives.push({
                name: name,
                model: textValue(device.model) || name,
                size: Number(device.size) || 0,
                driveType: driveType,
                media: media,
                fileSystems: fileSystems.join(" + ").toUpperCase(),
                state: state,
                percent: usage,
                freeBytes: freeBytes,
                usedBytes: usedBytes,
                totalBytes: usedBytes >= 0 && freeBytes >= 0 ? usedBytes + freeBytes : -1
            })
        }

        storageDrives = drives
        storageInventoryAvailable = true
    }

    function parseStorageTelemetry(text) {
        var fields = String(text || "").trim().split("|")
        if (fields.length < 3) {
            storageAvailable = false
            storagePercent = 0
            storageUsedBytes = 0
            storageTotalBytes = 0
            return
        }

        var percent = parseInt(fields[0])
        var used = parseFloat(fields[1])
        var total = parseFloat(fields[2])
        if (isNaN(percent) || isNaN(used) || isNaN(total) || total <= 0) {
            storageAvailable = false
            return
        }

        storageAvailable = true
        storagePercent = Math.max(0, Math.min(100, percent))
        storageUsedBytes = Math.max(0, used)
        storageTotalBytes = Math.max(0, total)
    }
"""

SAMPLERS = r"""
    FileView {
        id: systemCpuInfoFile
        path: "/proc/cpuinfo"
        onLoaded: theme.parseCpuInfo(systemCpuInfoFile.text())
    }

    FileView {
        id: systemLoadFile
        path: "/proc/loadavg"
        onLoaded: theme.parseSystemLoad(systemLoadFile.text())
    }

    FileView {
        id: kernelReleaseFile
        path: "/proc/sys/kernel/osrelease"
        onLoaded: theme.kernelRelease = String(kernelReleaseFile.text() || "").trim()
    }

    Process {
        id: cpuDetailProc
        command: ["bash", "-c",
            "sum=0; count=0; max=0; epp=''; governor=''; throttle=0; "
            + "for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do [[ -r $f ]] || continue; IFS= read -r v < \"$f\"; "
            + "[[ $v =~ ^[0-9]+$ ]] || continue; sum=$((sum + v)); count=$((count + 1)); done; "
            + "(( count > 0 )) && avg=$((sum / count / 1000)) || avg=0; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq; [[ -r $f ]] && { IFS= read -r v < \"$f\"; [[ $v =~ ^[0-9]+$ ]] && max=$((v / 1000)); }; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference; [[ -r $f ]] && IFS= read -r epp < \"$f\"; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor; [[ -r $f ]] && IFS= read -r governor < \"$f\"; "
            + "f=/sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count; [[ -r $f ]] && { IFS= read -r v < \"$f\"; [[ $v =~ ^[0-9]+$ ]] && throttle=$v; }; "
            + "printf '%s|%s|%s|%s|%s\\n' \"$avg\" \"$max\" \"$epp\" \"$governor\" \"$throttle\""]
        stdout: StdioCollector { onStreamFinished: theme.parseCpuDetail(this.text) }
    }

    Process {
        id: memoryHardwareProc
        command: ["bash", "-c",
            "if command -v inxi >/dev/null 2>&1; then LC_ALL=C inxi -m -c 0 --no-host 2>/dev/null; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: theme.parseMemoryHardware(this.text) }
    }

    Process {
        id: cpuTopProcessesProc
        command: ["ps", "-eo", "comm=,%cpu=", "--sort=-%cpu"]
        stdout: StdioCollector { onStreamFinished: theme.parseCpuTopProcesses(this.text) }
    }

    Process {
        id: gpuTelemetryProc
        command: ["bash", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then "
            + "IFS=, read -r name driver util temp used total clock power limit pstate fan < <(nvidia-smi --query-gpu=name,driver_version,utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.current.graphics,power.draw,power.limit,pstate,fan.speed --format=csv,noheader,nounits 2>/dev/null | head -n1); "
            + "if [[ $util =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $temp =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $used =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $total =~ ^[[:space:]]*[0-9]+[[:space:]]*$ ]]; then "
            + "printf 'nvidia|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$name\" \"$driver\" \"$util\" \"$temp\" \"$used\" \"$total\" \"$clock\" \"$power\" \"$limit\" \"$pstate\" \"$fan\"; exit 0; fi; "
            + "fi; "
            + "for busy in /sys/class/drm/card*/device/gpu_busy_percent; do "
            + "[[ -r $busy ]] || continue; read -r util < \"$busy\"; temp=0; "
            + "for sensor in \"${busy%/gpu_busy_percent}\"/hwmon/hwmon*/temp1_input; do "
            + "[[ -r $sensor ]] || continue; read -r raw < \"$sensor\"; temp=$((raw / 1000)); break; done; "
            + "printf 'sysfs|GPU||%s|%s|0|0|0|0|0||0\\n' \"$util\" \"$temp\"; exit 0; done; "
            + "printf 'none|||||||||||\\n'"]
        stdout: StdioCollector { onStreamFinished: theme.parseGpuTelemetry(this.text) }
    }

    Process {
        id: cpuTemperatureProc
        command: ["bash", "-c",
            "cpu=0; core=0; cpu_max=0; cpu_crit=0; nvme=0; nvme_max=0; nvme_crit=0; dimm=0; "
            + "for d in /sys/class/hwmon/hwmon*; do [[ -r $d/name ]] || continue; IFS= read -r name < \"$d/name\"; "
            + "case $name in coretemp|k10temp|zenpower|cpu_thermal) "
            + "for input in \"$d\"/temp*_input; do [[ -r $input ]] || continue; raw=0; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; "
            + "label_file=${input%_input}_label; label=''; [[ -r $label_file ]] && IFS= read -r label < \"$label_file\"; value=$((raw / 1000)); "
            + "case $label in 'Package id 0'|Tctl|Tdie|'CPU Package'|CPU) cpu=$value; max_file=${input%_input}_max; crit_file=${input%_input}_crit; "
            + "[[ -r $max_file ]] && { IFS= read -r v < \"$max_file\"; [[ $v =~ ^[0-9]+$ ]] && cpu_max=$((v / 1000)); }; "
            + "[[ -r $crit_file ]] && { IFS= read -r v < \"$crit_file\"; [[ $v =~ ^[0-9]+$ ]] && cpu_crit=$((v / 1000)); };; "
            + "Core*) (( value > core )) && core=$value;; esac; (( cpu == 0 )) && cpu=$value; done;; "
            + "nvme) for label_file in \"$d\"/temp*_label; do [[ -r $label_file ]] || continue; IFS= read -r label < \"$label_file\"; [[ $label == Composite ]] || continue; "
            + "input=${label_file%_label}_input; [[ -r $input ]] || continue; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; nvme=$((raw / 1000)); "
            + "max_file=${input%_input}_max; crit_file=${input%_input}_crit; [[ -r $max_file ]] && { IFS= read -r v < \"$max_file\"; [[ $v =~ ^[0-9]+$ ]] && nvme_max=$((v / 1000)); }; "
            + "[[ -r $crit_file ]] && { IFS= read -r v < \"$crit_file\"; [[ $v =~ ^[0-9]+$ ]] && nvme_crit=$((v / 1000)); }; break; done;; "
            + "jc42) for input in \"$d\"/temp*_input; do [[ -r $input ]] || continue; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; "
            + "value=$((raw / 1000)); (( value > dimm )) && dimm=$value; done;; esac; done; "
            + "if (( cpu == 0 )); then for zone in /sys/class/thermal/thermal_zone*; do [[ -r $zone/type && -r $zone/temp ]] || continue; "
            + "IFS= read -r type < \"$zone/type\"; case $type in x86_pkg_temp|cpu-thermal|cpu_thermal) IFS= read -r raw < \"$zone/temp\"; "
            + "[[ $raw =~ ^[0-9]+$ ]] && { cpu=$((raw / 1000)); break; };; esac; done; fi; "
            + "printf '%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$cpu\" \"$core\" \"$cpu_max\" \"$cpu_crit\" \"$nvme\" \"$nvme_max\" \"$nvme_crit\" \"$dimm\""]
        stdout: StdioCollector { onStreamFinished: theme.parseThermalTelemetry(this.text) }
    }

    Process {
        id: storageTelemetryProc
        command: ["bash", "-c",
            "LC_ALL=C df -P -B1 / 2>/dev/null | awk 'NR == 2 { gsub(/%/, \"\", $5); printf \"%s|%s|%s\\n\", $5, $3, $2 }'"]
        stdout: StdioCollector { onStreamFinished: theme.parseStorageTelemetry(this.text) }
    }

    Process {
        id: storageInventoryProc
        command: ["lsblk", "-J", "-b", "-o",
            "NAME,PATH,TYPE,SIZE,FSTYPE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS,MODEL,TRAN,ROTA,RM,HOTPLUG"]
        stdout: StdioCollector { onStreamFinished: theme.parseStorageInventory(this.text) }
    }
"""

TIMERS = r"""
    Timer {
        interval: 2500
        running: theme.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuDetailProc.running) cpuDetailProc.running = true
    }

    Timer {
        interval: 3000
        running: theme.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuTopProcessesProc.running) cpuTopProcessesProc.running = true
    }

    Timer {
        interval: 2500
        running: theme.modGpu || theme.gpuVisible || theme.thermalVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!gpuTelemetryProc.running) gpuTelemetryProc.running = true
    }

    Timer {
        interval: 5000
        running: theme.modCpuTemperature || theme.cpuVisible || theme.thermalVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuTemperatureProc.running) cpuTemperatureProc.running = true
    }

    Timer {
        interval: 30000
        running: theme.modStorage || theme.storageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!storageTelemetryProc.running) storageTelemetryProc.running = true
    }

    Timer {
        interval: theme.storageVisible ? 5000 : 60000
        running: theme.modStorage || theme.storageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!storageInventoryProc.running) storageInventoryProc.running = true
    }
"""

OLD_TIMER = '''    Timer {
        interval: (theme.modCpu || theme.cpuVisible || theme.modMemory || theme.memVisible) ? 2000 : 10000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            systemCpuFile.reload()
            systemMemFile.reload()
        }
    }'''

NEW_TIMER = '''    Timer {
        interval: (theme.modCpu || theme.cpuVisible || theme.modMemory || theme.memVisible) ? 2000 : 10000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            systemCpuFile.reload()
            systemLoadFile.reload()
            systemMemFile.reload()
        }
    }'''

MEM_FILEVIEW = '''    FileView {
        id: systemMemFile
        path: "/proc/meminfo"
        onLoaded: theme.parseSystemMem(systemMemFile.text())
    }'''

PARSE_MEM_TAIL = '''        systemMemCachedMiB = Math.round(cached / 1024)
    }'''

EDITS = [
    ("panelOuterBorderColor", "geometry",
     "    readonly property int   tileRadius:   pillRadius - 2",
     "after-line", PANEL_GEOMETRY),
    ("onGpuVisibleChanged", "panel visibility flags",
     '    onCpuVisibleChanged: popupOpened("cpuVisible")',
     "after-line", "\n" + VISIBILITY.rstrip("\n")),
    ("modCpuTemperature", "module flags",
     "    property bool modGpu:        true",
     "after-line", MODULE_FLAGS.rstrip("\n")),
    ("_systemCpuPrevUser", "cpu detail properties",
     "    property real _systemCpuPrevTotal: -1",
     "after-line", CPU_PROPS.rstrip("\n")),
    ("property string memoryType", "memory hardware properties",
     "    property int systemMemCachedMiB: 0",
     "after-line", MEM_PROPS.rstrip("\n")),
    ("gpuBackend", "telemetry properties",
     "    readonly property real systemMemTotalGiB: systemMemTotalMiB / 1024",
     "after-line", TELEMETRY_PROPS.rstrip("\n")),
    ("systemCpuUserPercent =", "parseSystemCpu merge",
     OLD_PARSE_CPU, "replace", NEW_PARSE_CPU),
    ("parseStorageInventory", "parser functions",
     PARSE_MEM_TAIL, "after", "\n" + NEW_FUNCS.strip("\n")),
    ("gpuTelemetryProc", "samplers",
     MEM_FILEVIEW, "after", "\n\n" + SAMPLERS.strip("\n")),
    ("systemLoadFile.reload", "loadavg in the shared reload timer",
     OLD_TIMER, "replace", NEW_TIMER),
    ("storageInventoryProc.running = true", "telemetry timers",
     NEW_TIMER, "after", "\n\n" + TIMERS.strip("\n")),
]


def strip_literals(src):
    """Blank out string, template, comment and regex literal bodies, keeping
    newlines so line numbers survive. Regex detection uses the last significant
    character, so `.replace(/[`]/g, ...)` cannot swallow the rest of the file."""
    out = []
    i, n = 0, len(src)
    prev = ""
    while i < n:
        c = src[i]
        if c in "\"'`":
            quote = c
            out.append(" ")
            i += 1
            while i < n:
                if src[i] == "\\":
                    out.append("  ")
                    i += 2
                    continue
                if src[i] == quote:
                    break
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            out.append(" ")
            i += 1
            prev = quote
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            out.append("  ")
            i += 2
            continue
        if c == "/" and prev in "(,=:[!&|?{};+-*%~^<>" :
            out.append(" ")
            i += 1
            while i < n and src[i] != "\n":
                if src[i] == "\\":
                    out.append("  ")
                    i += 2
                    continue
                if src[i] == "/":
                    break
                out.append(" ")
                i += 1
            out.append(" ")
            i += 1
            prev = "/"
            continue
        out.append(c)
        if not c.isspace():
            prev = c
        i += 1
    return "".join(out)


def balance(src, label):
    code = strip_literals(src)
    bad = []
    for open_c, close_c, name in (("{", "}", "brace"), ("(", ")", "paren"),
                                  ("[", "]", "bracket")):
        depth = 0
        for line_no, line in enumerate(code.split("\n"), 1):
            for ch in line:
                if ch == open_c:
                    depth += 1
                elif ch == close_c:
                    depth -= 1
                    if depth < 0:
                        bad.append("%s: unmatched closing %s at line %d"
                                   % (label, name, line_no))
                        depth = 0
        if depth != 0:
            bad.append("%s: %s balance ends at %+d" % (label, name, depth))
    return bad


def main():
    if not TARGET.is_file():
        sys.exit("not found: %s (run from the repo root, or pass a path)" % TARGET)
    src = TARGET.read_text()
    before = balance(src, "input")
    if before:
        sys.exit("refusing to patch, input is already unbalanced:\n  "
                 + "\n  ".join(before))

    applied, skipped = [], []
    for guard, label, anchor, mode, payload in EDITS:
        if guard in src:
            skipped.append(label)
            continue
        count = src.count(anchor)
        if count != 1:
            sys.exit("anchor for %r matched %d times, expected 1:\n%s"
                     % (label, count, anchor[:120]))
        if mode == "replace":
            src = src.replace(anchor, payload)
        else:
            end = src.index(anchor) + len(anchor)
            if mode == "after-line":
                end = src.index("\n", end)
                if not payload.startswith("\n"):
                    payload = "\n" + payload
            src = src[:end] + payload + src[end:]
        applied.append(label)

    problems = balance(src, "result")
    if problems:
        sys.exit("patched output is unbalanced, NOT writing:\n  "
                 + "\n  ".join(problems))

    if applied:
        shutil.copy2(TARGET, str(TARGET) + ".bak")
        TARGET.write_text(src)
    for name in applied:
        print("  +", name)
    for name in skipped:
        print("  =", name, "(already present)")
    print("%s: %d lines%s" % (TARGET, src.count("\n") + 1,
                              "" if applied else " (no changes)"))


if __name__ == "__main__":
    main()
