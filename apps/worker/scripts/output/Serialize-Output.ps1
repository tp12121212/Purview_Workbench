param([Parameter(Mandatory = $true)][object]$Result)

$Result | ConvertTo-Json -Depth 10
