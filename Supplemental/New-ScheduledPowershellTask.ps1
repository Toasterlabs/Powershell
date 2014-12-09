function New-ScheduledPowershellTask {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .PARAMETER 

    .PARAMETER 

    .LINK
    http://www.the-little-things.net
    .LINK
    https://github.com/zloeber/Powershell/
    .NOTES
    Last edit   :   
    Version     :   
    Author      :   Zachary Loeber

    .EXAMPLE


    Description
    -----------
    TBD
    #>
    [CmdLetBinding()]
    param(
        [Parameter(Position=0, HelpMessage='Task Name. If not set a random GUID will be used for the task name.')]
        [string]$TaskName,
        [Parameter(Position=1, HelpMessage='Task Description.')]
        [string]$TaskDescription,
        [Parameter(Position=2, HelpMessage='Task Script.')]
        [string]$TaskScript,
        [Parameter(Position=3, HelpMessage='Task Script Arguments.')]
        [string]$TaskScriptArgs,
        [Parameter(Position=4, HelpMessage='Task Start Time (defaults to 3AM tonight).')]
        [string]$TaskStartTime = $(Get-Date "$(((Get-Date).AddDays(1)).ToShortDateString()) 3:00 AM")
    )
    begin {
        # The Task Action command
        $TaskCommand = "c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"

        # The Task Action command argument
        $TaskArg = "-WindowStyle Hidden -NonInteractive -Executionpolicy unrestricted -command `"& `'$TaskScript`' $TaskScriptArgs`""
 
    }
    process {}
    end {
        try {
            # attach the Task Scheduler com object
            $service = new-object -ComObject("Schedule.Service")
            # connect to the local machine. 
            # http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx
            $service.Connect()
            $rootFolder = $service.GetFolder("\")
             
            $TaskDefinition = $service.NewTask(0) 
            $TaskDefinition.RegistrationInfo.Description = "$TaskDescription"
            $TaskDefinition.Settings.Enabled = $true
            $TaskDefinition.Settings.AllowDemandStart = $true
             
            $triggers = $TaskDefinition.Triggers
            #http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx
            $trigger = $triggers.Create(2) # Creates a daily trigger
            $trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
            $trigger.Enabled = $true
             
            # http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
            $Action = $TaskDefinition.Actions.Create(0)
            $action.Path = "$TaskCommand"
            $action.Arguments = "$TaskArg"
             
            #http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
            $rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"System",$null,5) | Out-Null
        }
        catch {
            throw
        }
    }
}