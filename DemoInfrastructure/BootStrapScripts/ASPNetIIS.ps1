Start-Transcript -path "C:\IISBootstrap.txt" -append 

Write-Output "Installing ASP.NET 4.5"
Dism /Online /Enable-Feature /FeatureName:IIS-ASPNET45 /All | Write-Output

Write-Output "Installing CertProvider"
Dism /Online /Enable-Feature /FeatureName:IIS-CertProvider /All | Write-Output

Write-Output "Installing IIS Management"
Dism /Online /Enable-Feature /FeatureName:IIS-ManagementService /All | Write-Output

Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install dotnet4.7.1 -y