<#
.SYNOPSIS
    Set the Processor affinity of a running Process.
.DESCRIPTION
    Set the Processor affinity for a running Process by specifying the CPU Cores that it can run on, and the name or PID of a Process(s).
.SYNTAX
    Set-ProcessCPUAffinity -Name <String[]> [-Cores <Int32[]>] [-PassThru] [<CommonParameters>]
    Set-ProcessCPUAffinity -Id <Int32[]> [-Cores <Int32[]>] [-PassThru] [<CommonParameters>]
    Set-ProcessCPUAffinity -Process <Process[]> [-Cores <Int32[]>] [-PassThru] [<CommonParameters>]
.PARAMETER ID
   The Process ID for the Process(es) to Set Affinity.
.PARAMETER Name
    The Process Name for the Process(es) to Set Affinity.
.PARAMETER Process
    Process objects from the pipeline or an existing array of System.Diagnostics.Process objects.
.PARAMETER Cores
    The cores that are allowed to run the Process.
    Separate each chosen core with a comma e.g. 1,3.
    Omit Parameter to set affinity to 100% CPU Cores.
.PARAMETER PassThru
    Return the updated process objects after the affinity is set.
.EXAMPLE
    Set-ProcessCPUAffinity -Cores 2 -Id 468
.EXAMPLE
    Set-ProcessCPUAffinity -Cores 1,3,4 -Name "Chrome"
.EXAMPLE
    Set-ProcessCPUAffinity -Name "Explorer"
.EXAMPLE
    Get-Process -Name chrome | Set-ProcessCPUAffinity -Cores 1,2 -PassThru
#>
function Set-ProcessCPUAffinity
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [Alias('Set-ProcessAffinity')]
    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Id')]
        [Alias('PID')]
        [int[]]
        $Id,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Name')]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Process')]
        [System.Diagnostics.Process[]]
        $Process,

        [Parameter()]
        [int[]]
        $Cores,

        [switch]
        $PassThru
    )

    begin
    {
        $LogicalProcessors = [Math]::Max(1, [int]$env:NUMBER_OF_PROCESSORS)

        if ($null -eq $Cores -or $Cores.Count -eq 0)
        {
            $Cores = 1..$LogicalProcessors
        }

        $Cores = @($Cores | Select-Object -Unique | Sort-Object)

        foreach ($Core in $Cores)
        {
            if ($Core -lt 1 -or $Core -gt $LogicalProcessors)
            {
                throw "Core '$Core' is outside the valid range 1..$LogicalProcessors."
            }
        }

        if ($LogicalProcessors -gt 63)
        {
            throw "This function supports a maximum of 63 logical processors in a single affinity mask."
        }

        [UInt64]$AffinityMask = 0
        foreach ($Core in $Cores)
        {
            $AffinityMask = [UInt64]($AffinityMask -bor ([UInt64]1 -shl ($Core - 1)))
        }

        $AffinityMaskPtr = [System.IntPtr]$AffinityMask
    }

    Process
    {
        [System.Diagnostics.Process[]]$ResultSet = @()

        switch ($PSCmdlet.ParameterSetName)
        {
            'Id'
            {
                foreach ($ProcID in $Id)
                {
                    $CurrentProcess = Get-Process -Id $ProcID -ErrorAction Stop
                    if ($PSCmdlet.ShouldProcess("$($CurrentProcess.ProcessName) (PID $($CurrentProcess.Id))", "Set processor affinity to cores $($Cores -join ', ' )"))
                    {
                        $CurrentProcess.ProcessorAffinity = $AffinityMaskPtr
                        $ResultSet += $CurrentProcess
                    }
                }
            }

            'Name'
            {
                foreach ($ProcessName in ($Name | Select-Object -Unique))
                {
                    foreach ($CurrentProcess in (Get-Process -Name $ProcessName -ErrorAction Stop))
                    {
                        if ($PSCmdlet.ShouldProcess("$($CurrentProcess.ProcessName) (PID $($CurrentProcess.Id))", "Set processor affinity to cores $($Cores -join ', ' )"))
                        {
                            $CurrentProcess.ProcessorAffinity = $AffinityMaskPtr
                            $ResultSet += $CurrentProcess
                        }
                    }
                }
            }

            'Process'
            {
                foreach ($CurrentProcess in $Process)
                {
                    if ($PSCmdlet.ShouldProcess("$($CurrentProcess.ProcessName) (PID $($CurrentProcess.Id))", "Set processor affinity to cores $($Cores -join ', ' )"))
                    {
                        $CurrentProcess.ProcessorAffinity = $AffinityMaskPtr
                        $ResultSet += $CurrentProcess
                    }
                }
            }
        }

        if ($PassThru)
        {
            $ResultSet
        }
    }
}
