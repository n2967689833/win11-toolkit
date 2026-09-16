Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

function Await($op, $resultType) {
    $t = $asTaskGeneric.MakeGenericMethod($resultType).Invoke($null, @($op))
    if (-not $t.Wait(25000)) { Write-Host "等待超时" }
    return $t.Result
}

[Windows.Devices.Enumeration.DeviceInformation, Windows.Devices.Enumeration, ContentType = WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.BluetoothDevice, Windows.Devices.Bluetooth, ContentType = WindowsRuntime] | Out-Null
[Windows.Devices.Radios.Radio, Windows.Devices.Radios, ContentType = WindowsRuntime] | Out-Null

Write-Host "==== 蓝牙无线电状态 ===="
try {
    $ro = [Windows.Devices.Radios.Radio]::GetRadiosAsync()
    $radios = Await $ro ([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]])
    foreach ($r in $radios) { Write-Host ("  " + $r.Name + " | " + $r.Kind + " | 状态=" + $r.State) }
} catch { Write-Host "  无线电查询失败: $($_.Exception.Message)" }

Write-Host ""
Write-Host "==== 已配对的蓝牙设备 ===="
try {
    $sel1 = [Windows.Devices.Bluetooth.BluetoothDevice]::GetDeviceSelectorFromPairingState($true)
    $op1 = [Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($sel1)
    $res1 = Await $op1 ([Windows.Devices.Enumeration.DeviceInformationCollection])
    foreach ($d in $res1) { Write-Host ("  " + $d.Name + " | " + $d.Id) }
    Write-Host ("  共 " + $res1.Count + " 个")
} catch { Write-Host "  查询失败: $($_.Exception.Message)" }

Write-Host ""
Write-Host "==== 附近可配对（未配对、在广播）的蓝牙设备 ===="
try {
    $sel2 = [Windows.Devices.Bluetooth.BluetoothDevice]::GetDeviceSelectorFromPairingState($false)
    $op2 = [Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($sel2)
    $res2 = Await $op2 ([Windows.Devices.Enumeration.DeviceInformationCollection])
    if ($res2.Count -eq 0) {
        Write-Host "  未发现任何未配对的蓝牙设备（说明附近没有设备在广播/配对模式）"
    } else {
        foreach ($d in $res2) { Write-Host ("  " + $d.Name + " | " + $d.Id) }
        Write-Host ("  共 " + $res2.Count + " 个")
    }
} catch { Write-Host "  查询失败: $($_.Exception.Message)" }
