function Condense-Enclosures {
    <#
    .SYNOPSIS
    Moves specified beginning enclosure types to the end of the prior line if found to be on its own line.
    .DESCRIPTION
    Moves specified beginning enclosure types to the end of the prior line if found to be on its own line.
    .PARAMETER Code
    Multiple lines of code to analyze
    .PARAMETER EnclosureStart
    Array of starting enclosure characters to process (default is (, {, @(, and @{)
    .EXAMPLE
    TBD

    Description
    -----------
    TBD

    .NOTES
    Author: Zachary Loeber
    Site: http://www.the-little-things.net/

    1.0.0 - 01/25/2015
    - Initial release
    #>
    [CmdletBinding()]
    param(
        [parameter(Position=0, ValueFromPipeline=$true, HelpMessage='Lines of code to look for and condense.')]
        [string[]]$Code,
        [parameter(Position=1, HelpMessage='Start of enclosure (typically left parenthesis or curly braces')]
        [string[]]$EnclosureStart = @('{','(','@{','@(')
    )
    begin {
        $Codeblock = @()
        $enclosures = @()
        $EnclosureStart | foreach {$enclosures += [Regex]::Escape($_)}
        $regex = '^\s*('+ ($enclosures -join '|') + ')\s*$'
        $Output = @()
        $Count = 0
        $LineCount = 0
    }
    process {
        $Codeblock += $Code
    }
    end {
#        try {
#            $ScriptBlock = [Scriptblock]::Create(($Codeblock | Out-String))
#            $Tokens = [Management.Automation.PSParser]::Tokenize($ScriptBlock, [ref]$null)
#        }
#        catch {
#            throw
#        }
        $Codeblock | Foreach {
            $LineCount++
            if (($_ -match $regex) -and ($Count -gt 0)) {
                $encfound = $Matches[1]
                if (-not ($Output[$Count - 1] -match '#')) { # if the prior line has any kind of comment/hash ignore it
                    Write-Verbose "Condense-Enclosures: Condensed enclosure $($encfound) at line $LineCount"
                    $Output[$Count - 1] = "$($Output[$Count - 1]) $($encfound)"
                }
                else {
                    $Output += $_
                    $Count++
                }
            }
            else {
                $Output += $_
                $Count++
            }
        }
        $Output
    }
}

function Convert-KeywordsAndOperatorsToLower {
    <#
    .SYNOPSIS
    Converts powershell keywords and operators to lowercase.
    .DESCRIPTION
    Converts powershell keywords and operators to lowercase.
    .PARAMETER Code
    Multiple lines of code to analyze
    .EXAMPLE
    TBD

    Description
    -----------
    TBD

    .NOTES
    Author: Zachary Loeber
    Site: http://www.the-little-things.net/

    1.0.0 - 01/25/2015
    - Initial release
    #>
    [CmdletBinding()]
    param(
        [parameter(Position=0, ValueFromPipeline=$true, HelpMessage='Lines of code to look for and condense.')]
        [string[]]$Code
    )
    begin {
        $Codeblock = @()
    }
    process {
        $Codeblock += $Code
    }
    end {
        $Codeblock = $Codeblock | Out-String

        $ScriptBlock = [Scriptblock]::Create($Codeblock)
        [Management.Automation.PSParser]::Tokenize($ScriptBlock, [ref]$null) | 
        Where {($_.Type -eq 'keyword') -or ($_.Type -eq 'operator') -and (($_.Content).length -gt 1)} | Foreach {
            $Convert = $false
            if (($_.Content -match "^-{1}\w{2,}$") -and ($_.Content -cmatch "[A-Z]") -and ($_.Type -eq 'operator') -or 
               (($_.Type -eq 'keyword') -and ($_.Content -cmatch "[A-Z]"))) {
                $Convert = $true
            }
            if ($Convert) {
                Write-Verbose "Convert-KeywordsAndOperatorsToLower: Converted keyword $($_.Content) at line $($_.StartLine)"
                $Codeblock = $Codeblock.Remove($_.Start,$_.Length)
                $Codeblock = $Codeblock.Insert($_.Start,($_.Content).ToLower())
            }
        }

        return $Codeblock
    }
}

function Pad-Operators {
    <#
    .SYNOPSIS
    Pads powershell operators with single spaces.
    .DESCRIPTION
    Pads powershell operators with single spaces.
    .PARAMETER Code
    Multiple lines of code to analyze
    .PARAMETER Operators
    Array of operator types to look for to pad. Defaults to +=,-=, and =.
    .EXAMPLE
    TBD

    Description
    -----------
    TBD

    .NOTES
    Author: Zachary Loeber
    Site: http://www.the-little-things.net/

    1.0.0 - 01/25/2015
    - Initial release
    #>
    [CmdletBinding()]
    param(
        [parameter(Position=0, ValueFromPipeline=$true, HelpMessage='Lines of code to look for and condense.')]
        [string[]]$Code,
        [parameter(Position=1, HelpMessage='Operator(s) to validate single spaces are around.')]
        [string[]]$Operators = @('+=','-=','=')
    )
    begin {
        $Codeblock = @()
        $ops = @()
        $Operators | foreach {$ops += [Regex]::Escape($_)}
        $Output = @()
        $LineCount = 0
        $regex = '\w+((\s*)(' + ($ops -join '|') + ')(\s*))\w*'
    }
    process {
        $Codeblock += $Code
    }
    end {
        $ScriptBlock = [Scriptblock]::Create(($Codeblock | Out-String))
        $Tokens = [Management.Automation.PSParser]::Tokenize($ScriptBlock, [ref]$null)
        $IgnoredLines = $Tokens | Where {($_.startline -ne $_.endline) -and (($_.Type -eq 'String') -or ($_.Type -eq 'Comment'))}
        $Codeblock | Foreach {
            $LineCount++
            $ToProcess = $true
            $CurLine = $_
            $IgnoredLines | Foreach {   # Skip any multiline comment or here-string/add-type variables
                if (($LineCount -ge $_.startline) -or ($LineCount -le $_.endline)) {
                    $ToProcess = $false
                }
            }
            if ($Curline -match '#') {  # Skip any line with a comment for now
                $ToProcess = $false
            }
            if ($ToProcess) {
                [regex]::Matches($CurLine,$regex) | foreach {
                    $prespace = $_.groups[2].Value
                    $matchedop = $_.groups[3].Value
                    $replacematch = [Regex]::Escape($_.groups[1].Value)
                    $postspace = $_.groups[4].Value
                    if (($prespace.length -ne 1) -or ($postspace.length -ne 1)) {
                        if ($matchedop -ne '=') {
                            $CurLine = $CurLine -replace $replacematch,(' ' + $matchedop + ' ')
                        }
                        else {
                            $replacer = '(?<!\+|-)' + [Regex]::Escape($matchedop)
                            $CurLine = $CurLine -replace $replacer,' = '
                        }
                        Write-Verbose "Operator padding corrected on line $($LineCount): $($matchedop)"
                    }
                }
            }
            $Output += $CurLine
        }
        return $Output
    }
}

function Expand-TypeAccelerators {
    [CmdletBinding()]
    param (
        [parameter(Position=0, ValueFromPipeline=$true, HelpMessage='Lines of code to to process.')]
        [string[]]$Code,
        [parameter(Position=1)]
        [switch]$AllTypes,
        [string]$SkipLinesContaining
    )
    begin {
        $accelerators = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')

        $accelhash = $accelerators::get
        $usedhash = @{}
        $accelhash.Keys | Foreach {
            if ($AllTypes) {
                $usedhash.$_ = $accelhash[$_].FullName
            }
            elseif ($accelhash[$_].FullName -notlike "System.*") {
                $usedhash.$_ = $accelhash[$_].FullName
            }
        }
    }
    
    process {
        $Codeblock += $Code
    }
    end {
        $ScriptBlock = [Scriptblock]::Create(($Codeblock | Out-String))
        $Tokens = [Management.Automation.PSParser]::Tokenize($ScriptBlock, [ref]$null)
        $ApplicableTokens = $Tokens | Where {($_.Type -eq 'Type') -or ($_.Type -eq 'CommandArgument')}
        $LinesWithTokens = $ApplicableTokens.StartLine | Sort-Object | Select -Unique
        $LinesWithTokens | Foreach {
            $tokenline = $_
            if ([string]::IsNullOrEmpty($SkipLinesContaining)) {
                $ProcessLine = $true
            }
            else {
                $ProcessLine = ($Codeblock[$tokenline] -notmatch [regex]::Escape($SkipLinesContaining))
            }
            if ($ProcessLine) {
                $ApplicableTokens | Where {$_.StartLine -eq $tokenline} | Foreach {
                    Write-Verbose "Expand-TypeAccelerators: Attempting to match $($_.Content) to existing token set..."
                    $keyval = $_.Content -replace '\[','' -replace '\]',''
                    if ($usedhash.ContainsKey($keyval)) {
                        Write-Verbose "Expand-TypeAccelerators: Found Match at line $tokenline for $($_.Content)"
                        Write-Verbose "Expand-TypeAccelerators: ....Updating to $($usedhash[$keyval])"
                        $Codeblock[$tokenline] = $Codeblock[$tokenline] -replace $keyval,$usedhash[$keyval]
                    }
                }
            }
        }

        return $Codeblock
    }
}
#
#
#$testfile = 'C:\Users\Zachary\Dropbox\Zach_Docs\Projects\Git\Powershell\Exchange\EWS\EWSFunctions.ps1'
#$test = Get-Content $testfile
#$test2 = $test | Expand-TypeAccelerators -Verbose # -SkipLinesContaining '[accelerator]::Add('
##$test |  clip