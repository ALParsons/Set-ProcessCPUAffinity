# Set-ProcessCPUAffinity
Set the Processor affinity for a running process by specifying the CPU cores that it can run on, and the name or PID of one or more processes.

## Usage

```powershell
. .\Set-ProcessCPUAffinity.ps1

Set-ProcessCPUAffinity -Id 468 -Cores 2
Set-ProcessCPUAffinity -Name "chrome" -Cores 1,3,4
Set-ProcessCPUAffinity -Name "Explorer"
Get-Process -Name chrome | Set-ProcessCPUAffinity -Cores 1,2 -PassThru
```

## Notes

- `-Id` accepts a PID or an array of PIDs. `-PID` is also accepted as an alias.
- `-Cores` is optional. When omitted, the function uses all available logical processors.
- `-PassThru` returns the updated `System.Diagnostics.Process` objects.
- `-WhatIf` is supported for previewing the change without applying it.
- The affinity mask is generated using the selected logical processor numbers; invalid core values raise an error before the change is applied.
