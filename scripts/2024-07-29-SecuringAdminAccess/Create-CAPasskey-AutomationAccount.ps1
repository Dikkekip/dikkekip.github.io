#Before running the script, be sure you're on the right subscription
#Set-AzContext -SubscriptionId $SubscriptionId
$ResourceGroup = 'identity-rg'
$AutomationAccount = 'd-identity-managment-01-at'
$Location = 'swedencentral'

[System.Collections.Generic.List[Object]]$InstalledModules = @()

# Check if the Automation Account exists
$AutomationAccountExists = Get-AzAutomationAccount -ResourceGroupName $ResourceGroup -Name $AutomationAccount -ErrorAction SilentlyContinue

if (-not $AutomationAccountExists) {
    Write-Host "Automation Account '$AutomationAccount' does not exist. Creating it..." -ForegroundColor Yellow
    New-AzAutomationAccount -ResourceGroupName $ResourceGroup -Name $AutomationAccount -Location $Location -Plan Basic -AssignSystemIdentity -ErrorAction Stop
    Write-Host "Automation Account '$AutomationAccount' created successfully." -ForegroundColor Green
} else {
    Write-Host "Automation Account '$AutomationAccount' already exists." -ForegroundColor Green
}

#Get top level graph module
$GraphModule = Find-Module Microsoft.Graph
$DependencyList = $GraphModule | select -ExpandProperty Dependencies | ConvertTo-Json | ConvertFrom-Json
$ModuleVersion = $GraphModule.Version

Write-Host "Starting installation of Microsoft Graph modules. Total modules to install: $($DependencyList.Count + 1)" -ForegroundColor Cyan

#Since we know the authentication module is a dependency, let us get that one first
$ModuleName = 'Microsoft.Graph.Authentication'
$ContentLink = "https://www.powershellgallery.com/api/v2/package/$ModuleName/$ModuleVersion"
Write-Host "Installing $ModuleName..." -ForegroundColor Yellow
New-AzAutomationModule -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -Name $ModuleName -ContentLinkUri $ContentLink -RuntimeVersion 7.2 -ErrorAction Stop | Out-Null
do {
    Start-Sleep 20
    $Status = Get-AzAutomationModule -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -RuntimeVersion "7.2" -Name $ModuleName | select -ExpandProperty ProvisioningState
    Write-Host "Status of "$ModuleName": $Status" -ForegroundColor Yellow
} until ($Status -in ('Failed','Succeeded'))

if ($Status -eq 'Succeeded') {
    $InstalledModules.Add($ModuleName)
    Write-Host "$ModuleName installed successfully." -ForegroundColor Green

    Write-Host "Starting installation of remaining modules..." -ForegroundColor Cyan
    foreach ($Dependency in $DependencyList) {
        $ModuleName = $Dependency.Name
        if ($ModuleName -notin $InstalledModules) {
            $ContentLink = "https://www.powershellgallery.com/api/v2/package/$ModuleName/$ModuleVersion"
            Write-Host "Initiating installation of $ModuleName..." -ForegroundColor Yellow
            New-AzAutomationModule -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -ContentLinkUri $ContentLink -Name $ModuleName -RuntimeVersion 7.2 -ErrorAction Stop | Out-Null
            sleep 3
        }
    }

    $LoopIndex = 0
    $TotalModules = $DependencyList.Count + 1
    $LastProgress = 0
    do {
        $CurrentProgress = [math]::Round(($InstalledModules.Count / $TotalModules) * 100)
        if ($CurrentProgress -gt $LastProgress) {
            Write-Host "Progress: $CurrentProgress% ($($InstalledModules.Count) / $TotalModules modules installed)" -ForegroundColor Cyan
            $LastProgress = $CurrentProgress
        }

        foreach ($Dependency in $DependencyList) {
            $ModuleName = $Dependency.Name
            if ($ModuleName -notin $InstalledModules) {
                $Status = Get-AzAutomationModule -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccount -Name $ModuleName -ErrorAction SilentlyContinue | select -ExpandProperty ProvisioningState
                Write-Host "Module $ModuleName status: $Status" -ForegroundColor Yellow -NoNewline
                Write-Host "`r" -NoNewline
                if ($Status -in ('Failed','Succeeded')) {
                    if ($Status -eq 'Succeeded') {
                        $InstalledModules.Add($ModuleName)
                        Write-Host "Module $ModuleName installed successfully." -ForegroundColor Green
                    } else {
                        Write-Host "Module $ModuleName failed to install." -ForegroundColor Red
                    }
                }
                sleep 3
            }
        }
        $LoopIndex++
    } until (($InstalledModules.Count -ge $TotalModules) -or ($LoopIndex -ge 10))
}

$FinalProgress = [math]::Round(($InstalledModules.Count / $TotalModules) * 100)
Write-Host "Installation process completed. Progress: $FinalProgress% ($($InstalledModules.Count) / $TotalModules modules installed)" -ForegroundColor Cyan
if ($InstalledModules.Count -lt $TotalModules) {
    Write-Host "Some modules may have failed to install. Please check the Azure portal for more details." -ForegroundColor Yellow
}