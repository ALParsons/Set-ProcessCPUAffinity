<#
.SYNOPSIS
    Set the Processor affinity of a running Process.
.DESCRIPTION
    Set the Processor affinity for a running Process by specifying the CPU Cores that it can run on, and the name or PID of a Process(s).
.SYNTAX
    Set-ProcessCPUAffinity -Name <String[]> -Cores <Int32[]> [<CommonParameters>]
    Set-ProcessCPUAffinity -Id <Int32[]> -Cores <Int32[]> [<CommonParameters>]
.PARAMETER ID
   The Process ID for the Process(es) to Set Affinity.
.PARAMETER Name
    The Process Name for the Process(es) to Set Affinity.
.PARAMETER Cores
    The cores that are allowed to run the Process.
    Separate each chosen core with a comma e.g. 1,3.
    Omit Parameter to set affinity to 100% CPU Cores.
.EXAMPLE
    Set-ProcessCPUAffinity -Cores 2 -PID 468
.EXAMPLE
    Set-ProcessCPUAffinity -Cores 1,3,4 -Name "Chrome"
.EXAMPLE
    Set-ProcessCPUAffinity -Name "Explorer"
#>
function Set-ProcessCPUAffinity
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName="Id")]
        [int[]]
        $Id
    )

    DynamicParam
    {
            # Set the dynamic parameters' name
            $ParameterName1 = 'Cores'
            $ParameterName2 = 'Name'

            # Create the dictionary
            $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

            # Create the collection of attributes
            $AttributeCollection1 = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $AttributeCollection2 = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

            # Create and set the parameters' attributes
            $ParameterAttribute1 = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute1.Mandatory = $false

            $ParameterAttribute2 = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute2.Mandatory = $true
            $ParameterAttribute2.ParameterSetName = "Name"

            # Add the attributes to the attributes collection
            $AttributeCollection1.Add($ParameterAttribute1)
            $AttributeCollection2.Add($ParameterAttribute2)

            # Generate and set the ValidateSet
            [int[]]$arrCPUSet = $null
            [int[]]$arrCPUSet += (1..$env:NUMBER_OF_PROCESSORS)
            $ValidateSetAttribute1 = New-Object System.Management.Automation.ValidateSetAttribute($arrCPUSet)

            [string[]]$arrNameSet = $null
            [string[]]$arrNameSet += (Get-Process).Name | Select-Object -Unique
            $ValidateSetAttribute2 = New-Object System.Management.Automation.ValidateSetAttribute($arrNameSet)

            # Add the ValidateSet to the attributes collection
            $AttributeCollection1.Add($ValidateSetAttribute1)
            $AttributeCollection2.Add($ValidateSetAttribute2)

            # Create and return the dynamic parameter
            $RuntimeParameter1 = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName1, [int[]], $AttributeCollection1)
            $RuntimeParameter2 = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName2, [string[]], $AttributeCollection2)

            $RuntimeParameterDictionary.Add($ParameterName1, $RuntimeParameter1)
            $RuntimeParameterDictionary.Add($ParameterName2, $RuntimeParameter2)


            return $RuntimeParameterDictionary
    }

    begin
    {
        # Bind the parameter to a friendly variable
        $Cores = $PsBoundParameters['Cores']
        $Name  = IF ($null -ne $PsBoundParameters['Name']) { $PsBoundParameters['Name'] }

        [int]$LogicalProcessors = $env:NUMBER_OF_PROCESSORS

        # Instantiate CPU counters & array
        [int]$CPUid = 1
        [int]$Counter = 1
        [array]$CPUs = @()


        # Build CPU array for filtering the chosen CPU's Affinity mask
        Do
        {
            # Create a CPU Object to add to the CPU array
            $CPUObj = New-Object -TypeName PSCustomObject
            $CPUObj | Add-Member -Name "CPUid" -MemberType NoteProperty -Value $CPUid
            $CPUObj | Add-Member -Name "CPU#" -MemberType NoteProperty -Value "CPU$Counter"

            # Add CPU to array
            $CPUs += $CPUObj

            # Increment CPU object counters
            $CPUid = $CPUid * 2 ; $Counter++

        } Until ($Counter -gt $LogicalProcessors)

        # If Cores is ommited, declare all cores for affinity
        IF ($null -eq $Cores) {[string[]]$Cores = (1..$env:NUMBER_OF_PROCESSORS)}

        # Remove possible repeated CPU ID's
        $Cores = $Cores | Select-Object -Unique

        # Filter the CPU array to the CPU's selected for affinity
        $AffinityCores = foreach ($Core in $Cores) { $CPUs | Where-Object { $_."CPU#" -match $Core } }

        # Create Affinity mask for the selected CPU's
        [int]$AffinityMask = 0
        $AffinityCores | ForEach-Object { $AffinityMask += $_.CPUid }

    }

    Process
    {

        # Set Process collection and Process Identifier (ID vs. Name)
        [String[]]$Processes = IF ($null -ne $Name) { $Name ; $Identifier = "Name" } Else { $Id ; $Identifier = "Id" }


        # Switch to code block for the selected Process Identifier
        # Set CPU affinity mask for each selected Process
        [System.Diagnostics.Process[]]$ResultSet = @()
        Switch($Identifier)
        {
            Name
            {
                $Processes = $Processes | Select-Object -Unique
                Foreach ($Process in $Processes)
                {
                    Foreach ($ProcID in (Get-Process -Name $Process).Id)
                    {
                        (Get-Process -Id $ProcID).ProcessorAffinity = $AffinityMask
                        $ResultSet += Get-Process -Id $ProcID
                    }

                }
            }

            Id
            {
                Foreach ($Process in $Processes)
                {
                    (Get-Process -Id $Process).ProcessorAffinity = $AffinityMask
                    $ResultSet += Get-Process -Id $Process
                }
            }

        }

        # Return array of System.Diagnostic.Process objects to the pipeline
        $ResultSet
    }

}