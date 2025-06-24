#Requires -RunAsAdministrator
#Requires -Version 7.4

using namespace System.Collections.Generic
using namespace System.ComponentModel
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Runtime.InteropServices
using namespace System.Security.Principal
using namespace System.Text

[Console]::OutputEncoding = [Console]::InputEncoding = $OutputEncoding = [UTF8Encoding]::new()

Import-Module -Name PwshSpectreConsole

$ErrorActionPreference = 'Stop'

# Needs to be global for Register-EngineEvent -Action
$Global:SniffResults = [List[object]]::new()
$Global:SniffFound = $false
$Global:SniffImage = $null
$Script:SniffEventName = 'SnifEventId'

Function Get-ContextSubstring {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $InputString,

        [Parameter(Mandatory)]
        [int]
        $Index,

        [Parameter(Mandatory)]
        [int]
        $Length,

        [Parameter(Mandatory)]
        [int]
        $Extra
    )

    process {
        $startIndex = [Math]::Max(0, $Index - $Extra)
        $endIndex = [Math]::Min($InputString.Length, $Index + $Length + $Extra)

        $prefix = ""
        if ($startIndex -gt 0) {
            $prefix = "..."
        }

        $suffix = ""
        if ($endIndex -lt $InputString.Length) {
            $suffix = "..."
        }

        $context = $InputString.Substring($startIndex, $endIndex - $startIndex)
        $relativeStart = $Index - $startIndex
        $relativeEnd = $relativeStart + $Length

        @(
            $prefix
            $context.Substring(0, $relativeStart)
            "[red]"
            $context.Substring($relativeStart, $Length)
            "[/]"
            $context.Substring($relativeEnd)
            $suffix
        ) -join ""
    }
}

Function Write-SniffEvent {
    [OutputType([void])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $EventType,

        [Parameter(Mandatory)]
        [string]
        $Message,

        [Parameter(Mandatory)]
        [string]
        $Detail
    )

    $null = $Script:MainRunspace.Events.GenerateEvent(
        $Script:SniffEventName,
        $null,
        $null,
        @{
            EventType = $EventType
            Message = $Message
            Detail = $Detail
        })
}

Function Start-SniffThreadJob {
    [OutputType([Job2])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $EventType,

        [Parameter(Mandatory)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Pattern
    )

    $script = {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [Runspace]
            $Runspace,

            [Parameter(Mandatory)]
            [string]
            $SniffEventName,

            [Parameter(Mandatory)]
            [ScriptBlock]
            $WriteSniffEvent,

            [Parameter(Mandatory)]
            [ScriptBlock]
            $GetContextSubstring,

            [Parameter(Mandatory)]
            [string]
            $EventType,

            [Parameter(Mandatory)]
            [string]
            $Path,

            [Parameter()]
            [System.Collections.IDictionary]
            $SniffParam
        )

        $ErrorActionPreference = 'Stop'
        $PSDefaultParameterValues['Write-SniffEvent:EventType'] = $EventType

        $Script:SniffEventName = $SniffEventName
        $Script:MainRunspace = $Runspace
        ${Function:Write-SniffEvent} = $WriteSniffEvent.Ast.Body.GetScriptBlock()
        ${Function:Get-ContextSubstring} = $GetContextSubstring.Ast.Body.GetScriptBlock()

        . $Path
        Start-SniffCapture @SniffParam
    }

    $sniffParams = @{}
    if ($Pattern) {
        $sniffParams.Pattern = $Pattern
    }

    $threadParams = @{
        ScriptBlock = $script
        ArgumentList = @(
            [Runspace]::DefaultRunspace
            $Script:SniffEventName
            ${Function:Write-SniffEvent}
            ${Function:Get-ContextSubstring}
            $EventType
            $Path
            $sniffParams
        )
    }
    Start-ThreadJob @threadParams
}

$availableTasks = @(
    Get-ChildItem -LiteralPath $PSScriptRoot -Include *.Sniffer.ps1 |
        ForEach-Object -Process {
            $path = $_.FullName
            $metadata = Start-ThreadJob -ScriptBlock {
                . $using:path
                Get-SniffMetadata
            } | Receive-Job -Wait -AutoRemoveJob

            [PSCustomObject]@{
                Id = $metadata.Id
                Description = $metadata.Description
                RequiresPattern = $metadata.RequiresPattern
                Path = $path
                PreviousState = $null
            }
        }
)

$prompt = @{
    Message = "Select the sniffing methods to enable"
    Choices = $availableTasks
    ChoiceLabelProperty = 'Description'
}
$choices = Read-SpectreMultiSelection @prompt

$pattern = $null
if (@($choices.RequiresPattern | Where-Object { $_ -eq  $true }).Count) {
    $pattern = Read-Host -Prompt "Enter regex pattern to search for (default 'password')"
    if (-not $pattern) {
        $pattern = 'password'
    }
}

$jobs = [List[Job2]]::new()
$sniffEvent = Register-EngineEvent -SourceIdentifier $Script:SniffEventName -Action {
    $Global:SniffFound = $true
    $Global:SniffImage = Get-ChildItem -LiteralPath "$PSScriptRoot\Assets" |
        Select-Object -ExpandProperty FullName |
        Get-Random
    $Global:SniffResults.Add($event.MessageData)
}
try {
    foreach ($choice in $choices) {
        Write-SpectreHost "[grey]STARTUP:[/] Enabling $($choice.Description)"

        $path = $choice.Path
        $choice.PreviousState = Start-ThreadJob -ScriptBlock {
            . $using:path
            Enable-SniffMonitoring
        } | Receive-Job -Wait -AutoRemoveJob

        $jobParams = @{}
        if ($choice.RequiresPattern) {
            $jobParams.Pattern = $pattern
        }

        $job = Start-SniffThreadJob -EventType $choice.Id -Path $choice.Path @jobParams
        $jobs.Add($job)
    }

    Write-SpectreHost "[grey]STARTUP:[/] Reticulating splines"

    $layout = New-SpectreLayout -Name "root" -Rows @(
        New-SpectreLayout -Name "title" -MinimumSize 3 -Ratio 1
        New-SpectreLayout -Name "content" -Ratio 3 -Columns @(
            New-SpectreLayout -Name "description" -Ratio 2
            New-SpectreLayout -Name "photo-root" -Ratio 1 -Rows @(
                New-SpectreLayout -Name "photo" -Ratio 2
                New-SpectreLayout -Name "caption" -MinimumSize 1 -Ratio 1
            )
        )
        New-SpectreLayout -Name "details" -Ratio 2
    )

    Invoke-SpectreLive -Data $layout -ScriptBlock {
        param (
            [Spectre.Console.LiveDisplayContext]
            $Context
        )

        $currentSelection = 0
        while ($true) {
            $titlePanel = @(
                "Smuggling data between PowerShell processes like Han Solo - PSConfEU 2025 [gray]Imperial Secret Sniffer[/]"
                "(Esc) or (q) quit, (↑) up, (↓) down, (c) clear"
             ) -join "`n" |
                Format-SpectreAligned -HorizontalAlignment Center -VerticalAlignment Middle |
                Format-SpectrePanel -Expand

            $contentList = @($Global:SniffResults | ForEach-Object -Process {
                "$($_.EventType) - $($_.Message)"
            })
            if (-not $contentList) {
                $contentList = @("None found")
            }

            $lastKeyPressed = $null
            while ([Console]::KeyAvailable) {
                $lastKeyPressed = [Console]::ReadKey($true)
            }

            if ($lastKeyPressed -ne $null) {
                if ($lastKeyPressed.Key -eq "DownArrow") {
                    $currentSelection = ($currentSelection + 1) % $contentList.Count
                    $Global:SniffFound = $false
                }
                elseif ($lastKeyPressed.Key -eq "UpArrow") {
                    $currentSelection = ($currentSelection - 1 + $contentList.Count) % $contentList.Count
                    $Global:SniffFound = $false
                }
                elseif ($lastKeyPressed.Key -eq "Escape" -or $lastKeyPressed.Key -eq "q") {
                    return
                }
                elseif ($lastKeyPressed.Key -eq "c") {
                    $currentSelection = 0
                    $Global:SniffResults = [List[object]]::new()
                    $Global:SniffFound = $false
                    continue
                }
            }

            $contentList[$currentSelection] = $contentList[$currentSelection]
            $detail = "..."
            if ($Global:SniffResults) {
                $contentList[$currentSelection] = "[Turquoise2]$($contentList[$currentSelection])[/]"
                $detail = $Global:SniffResults[$currentSelection].Detail
            }

            $descriptionPanel = Format-SpectrePanel -Header "[white]Found[/]" -Data ($contentList -join "`n") -Expand
            $photoPanel, $photoCaption = if ($Global:SniffFound -and (Get-Date).Second % 3) {
                Get-SpectreImage -ImagePath $Global:SniffImage | Format-SpectrePanel -Border None
                "[red]Secret Found, Tie Fighters are on their way[/]" |
                    Format-SpectreAligned -HorizontalAlignment Center -VerticalAlignment Middle
            }
            else {
                Format-SpectrePanel -Data "" -Border None
                Format-SpectrePanel -Data "" -Border None
            }
            $detailsPanel = Format-SpectrePanel -Header "[white]Details[/]" -Data $detail -Expand

            $layout["title"].Update($titlePanel) | Out-Null
            $layout["description"].Update($descriptionPanel) | Out-Null
            $layout["photo"].Update($photoPanel) | Out-Null
            $layout["caption"].Update($photoCaption) | Out-Null
            $layout["details"].Update($detailsPanel) | Out-Null

            $Context.Refresh()
            Start-Sleep -Milliseconds 100
        }
    }
}
finally {
    Unregister-Event -SourceIdentifier $Script:SniffEventName
    $sniffEvent | Remove-Job -Force

    $jobs | Stop-Job -PassThru | Remove-Job -Force

    foreach ($choice in $choices) {
        $path = $choice.Path
        if ($choice.PreviousState) {
            $null = Start-ThreadJob -ScriptBlock {
                . $using:path
                $args[0] | Disable-SniffMonitoring
            } -ArgumentList $choice.PreviousState | Receive-Job -Wait -AutoRemoveJob
        }
    }
}
