$data = Import-Csv -Path './windows11_builds_full.csv' -Delimiter ';'
Write-Host "Spalten:" $data[0].PSObject.Properties.Name
Write-Host ""
Write-Host "Erste 3 Builds:"
$data | Select-Object -First 3 | ForEach-Object { Write-Host "  Build: '$($_.Build)'" }
Write-Host ""
Write-Host "Suche nach 26100.7171:"
$found = $data | Where-Object { $_.Build -eq '26100.7171' }
if ($found) { 
    Write-Host "  Gefunden!" -ForegroundColor Green 
    Write-Host "  Details: $($found.Build) - $($found.'Release-Datum')"
} else { 
    Write-Host "  Nicht gefunden" -ForegroundColor Red 
}
Write-Host ""
Write-Host "Alle 26100 Builds (erste 10):"
$data | Where-Object { $_.Build -like '26100.*' } | Select-Object -First 10 | ForEach-Object { Write-Host "  $($_.Build)" }
