# === CONFIG ===
$baseExeName    = "t7es3sca"
$scriptName     = "doasca.ahk"
$ahk2exePath    = "ahk\Compiler\Ahk2Exe.exe"
$upxPath        = "upx\upx.exe"
$mediaFolder    = "t7es3_media"
$iconPath       = "t7es3_media\default.ico"
$iniPath        = "doa.ini"
$licensePath    = "LICENSE"
$readmePath     = "README.txt"
$toolsFolder    = "t7es3_tools"
$versionDat     = "version.dat"
$versionTxt     = "version.txt"
$versionTpl     = "version_template.txt"
$extraAssets    = @($readmePath, $iniPath, $licensePath, $versionTxt, $versionDat)


# === CLEAN-UP ===
Write-Host ":: Cleaning up..."
if (Test-Path "new_builds")
{
Remove-Item -Recurse -Force "new_builds"
Write-Host ":: Removed new_builds folder"
}

# === GET ENVIRONMENT INFO ===
$localTag  = "LocalBuild_" + (Get-Date -Format "yyyyMMdd_HHmmss")
$finalExe  = "${baseExeName}${localTag}.exe"
$zipName   = "${baseExeName}${localTag}.zip"


# === TIMESTAMP (Only define $timestamp if you need it for logging) ===
$timestamp = Get-Date -Format "yyyyMMdd_HH"


# === VERSIONING ===
Copy-Item $versionTpl $versionTxt -Force
(Get-Content $versionTxt) -replace "%%DATETIME%%", $timestamp | Set-Content $versionTxt
$timestamp | Set-Content $versionDat


# === CLEANUP OLD FILES ===
Remove-Item "$baseExeName.exe","$finalExe","build.log","$zipName" -ErrorAction SilentlyContinue


# === COMPILE SCRIPT ===
Write-Host ":: Compiling AHK..."

# Show current working directory
Write-Host ":: Current directory: $(Get-Location)"

# Verify all paths
Write-Host ":: Path verification:" -ForegroundColor Yellow
Write-Host ":: Script: $scriptName (exists: $(Test-Path $scriptName))"
Write-Host ":: Ahk2Exe: $ahk2exePath (exists: $(Test-Path $ahk2exePath))"
Write-Host ":: UPX: $upxPath (exists: $(Test-Path $upxPath))"
Write-Host ":: MediaFolder: $mediaFolder (exists: $(Test-Path $mediaFolder))"
Write-Host ":: Icon: $iconPath (exists: $(Test-Path $iconPath))"
Write-Host ":: Ini: $iniPath (exists: $(Test-Path $iniPath))"
Write-Host ":: License: $licensePath (exists: $(Test-Path $licensePath))"
Write-Host ":: Readme: $readmePath (exists: $(Test-Path $readmePath))"
Write-Host ":: Tools: $toolsFolder (exists: $(Test-Path $toolsFolder))"
Write-Host ":: Dat: $versionDat (exists: $(Test-Path $versionDat))"
Write-Host ":: Txt: $versionTxt (exists: $(Test-Path $versionTxt))"
Write-Host ":: Template: $versionTpl (exists: $(Test-Path $versionTpl))"
Write-Host ":: Output will be: $baseExeName.exe"

# Build the argument list with proper quoting
$arguments = @(
    "/in", $scriptName,
    "/out", "$baseExeName.exe",
    "/icon", $iconPath
)

Write-Host ":: Full command:" -ForegroundColor Cyan
Write-Host ":: `"$ahk2exePath`" $($arguments -join ' ')"

# Execute with detailed error capture
Write-Host ":: Executing..." -ForegroundColor Green
$process = Start-Process -FilePath $ahk2exePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow

Write-Host ":: Process exit code: $($process.ExitCode)"

# Check if output file was created
if (Test-Path "$baseExeName.exe") {
    Write-Host ":: Compilation successful!" -ForegroundColor Green
    Copy-Item "$baseExeName.exe" "$finalExe" -Force
    Write-Host ":: Copied $baseExeName.exe to $finalExe (timestamped build EXE)"
} else {
    Write-Host ":: Output file not created!" -ForegroundColor Red
    Write-Error "Compilation failed."
    Exit 1
}


# === COMPRESS EXE ===
Write-Host ":: Compressing exe..." -ForegroundColor Cyan
Write-Host ":: Pre-UPX size:" (Get-Item $finalExe).Length
$upxResult = & $upxPath --best --lzma $finalExe
$upxResult | ForEach-Object { Write-Host $_ }
Write-Host ":: Post-UPX size:" (Get-Item $finalExe).Length
Write-Host ":: UPX compression finished."


# === ZIP CONTENTS ===
Write-Host ":: Creating ZIP: $zipName"

# Build file list
$allFiles = @()

# Add final executable
if (Test-Path $finalExe) {
    $allFiles += $finalExe
    Write-Host ":: Added: $finalExe"
} else {
    Write-Host ":: Warning: $finalExe not found!" -ForegroundColor Yellow
}

# Add extra assets
foreach ($asset in $extraAssets) {
    if (Test-Path $asset) {
        $allFiles += $asset
        Write-Host ":: Added: $asset"
    } else {
        Write-Host ":: Warning: $asset not found!" -ForegroundColor Yellow
    }
}

# Add media files
if (Test-Path $mediaFolder) {
    $mediaFiles = Get-ChildItem -Path $mediaFolder -File | ForEach-Object { $_.FullName }
    $allFiles += $mediaFiles
    Write-Host ":: Added $($mediaFiles.Count) files from $mediaFolder"
} else {
    Write-Host ":: Warning: $mediaFolder not found!" -ForegroundColor Yellow
}

# Add tools folder files
if (Test-Path $toolsFolder) {
    $toolsFiles = Get-ChildItem -Path $toolsFolder -Recurse | Where-Object { !$_.PSIsContainer } | ForEach-Object { $_.FullName }
    if ($toolsFiles) {
        $allFiles += $toolsFiles
        Write-Host ":: Added $($toolsFiles.Count) files from $toolsFolder"
    }
} else {
    Write-Host ":: Warning: $toolsFolder not found!" -ForegroundColor Yellow
}

# Add placeholder files for empty folders
foreach ($folder in $emptyFolders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    $placeholderPath = "$folder\.placeholder"
    New-Item -Path $placeholderPath -ItemType File -Force | Out-Null
    $allFiles += $placeholderPath
    Write-Host ":: Added placeholder: $placeholderPath"
}

# Remove any missing paths
$allFiles = $allFiles | Where-Object { Test-Path $_ }

Write-Host ":: Total files to zip: $($allFiles.Count)"

# Create build staging folder
$stagingFolder = "build_temp"
Remove-Item $stagingFolder -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingFolder | Out-Null

# Copy all files into staging while preserving folder structure
foreach ($file in $allFiles) {
    $relativePath = Resolve-Path -Relative $file
    $destination = Join-Path $stagingFolder $relativePath
    $destinationDir = Split-Path $destination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item $file -Destination $destination -Force
}

# Create ZIP from staging
try {
    Compress-Archive -Path "$stagingFolder\*" -DestinationPath $zipName -Force
    Write-Host ":: ZIP created successfully: $zipName" -ForegroundColor Green
} catch {
    Write-Host ":: ZIP creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Remove-Item $stagingFolder -R
Write-Host ":: Fallback EXE created!" -ForegroundColor Yellow
Write-Host ":: `n:: ===== BUILD COMPLETE =====" -ForegroundColor Cyan
Write-Host ":: Output EXE: $finalExe"
Write-Host ":: ZIP Archive: $zipName"
Write-Host ":: Timestamp: $timestamp"


# === MOVE OUTPUT TO NEW_BUILDS FOLDER ===
try {
    $buildFolder = "C:\repos\t7es3-screen-capture-advanced\new_builds"
    $outputFiles = @(
        $finalExe,
        $zipName,
        "$baseExeName.exe"
    )

    # Ensure $buildFolder is a proper directory
    if (Test-Path $buildFolder) {
        $item = Get-Item $buildFolder
        if (-not $item.PSIsContainer) {
            Write-Host ":: Removing file named 'new_builds' so we can create a folder instead..."
            Remove-Item $buildFolder -Force
        }
    }

    if (-not (Test-Path $buildFolder)) {
        Write-Host ":: Creating build folder: $buildFolder"
        New-Item -ItemType Directory -Path $buildFolder | Out-Null
    }

    # Move files to build folder
    foreach ($file in $outputFiles) {
        if (Test-Path $file) {
            Write-Host ":: Moving $file to $buildFolder"
            Move-Item $file -Destination $buildFolder -Force
        } else {
            Write-Warning "File not found, skipping: $file"
        }
    }

    Write-Host ":: All available files moved to: $buildFolder"
}
catch {
    Write-Error "Error moving build files: $_"
}


# === LOG SUCCESS ===
"[$timestamp] Built $finalExe with embedded files" | Add-Content "changelog.txt"
Write-Host ":: Done: $finalExe + $zipName"

Write-Host ":: Script completed!" -ForegroundColor Green

# Open folder of the moved executable
$finalExeMoved = Join-Path $buildFolder (Split-Path $finalExe -Leaf)
if (Test-Path $finalExeMoved) {
    Invoke-Item (Get-Item $finalExeMoved).DirectoryName
} else {
    Write-Warning ":: Moved file not found: $finalExeMoved"
}

