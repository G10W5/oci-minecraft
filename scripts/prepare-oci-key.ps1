# Prepares the one secret that is awkward to produce by hand.
#
# OCI needs the API signing private key as base64 text when it has to live in a
# GitHub secret (PEM files contain newlines, which secrets handle badly).
#
# Usage:
#   1. OCI Console -> profile menu -> My profile -> API keys -> Add API key
#      -> Generate API key pair -> Download private key  (saves oci_api_key.pem)
#   2. Move that file somewhere, then:
#      powershell -ExecutionPolicy Bypass -File scripts\prepare-oci-key.ps1 -Pem "$HOME\Downloads\oci_api_key.pem"
#   3. The base64 blob is on your clipboard: paste it into the
#      OCI_PRIVATE_KEY_B64 repository secret.

param(
    [Parameter(Mandatory = $true)]
    [string]$Pem
)

$path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Pem)
if (-not (Test-Path -LiteralPath $path)) {
    throw "Not found: $path"
}

$text = Get-Content -LiteralPath $path -Raw
if ($text -notmatch 'BEGIN .*PRIVATE KEY') {
    throw "That file does not look like a PEM private key (no BEGIN ... PRIVATE KEY line)."
}

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
$outFile = Join-Path $PSScriptRoot '..\.oci-key-b64.txt'
Set-Content -LiteralPath $outFile -Value $b64 -NoNewline
Set-Clipboard -Value $b64

Write-Host ''
Write-Host "Base64 written to: $outFile" -ForegroundColor Green
Write-Host "Also copied to your clipboard - paste it into the OCI_PRIVATE_KEY_B64 secret." -ForegroundColor Green
Write-Host "Length: $($b64.Length) characters"
Write-Host ''
Write-Host 'Delete .oci-key-b64.txt afterwards:'
Write-Host "  Remove-Item `"$outFile`""
