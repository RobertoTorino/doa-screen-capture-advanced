param(
    [string]$Message = "Automated commit"
)

# Ensure Git LFS is initialized (only needs to run once per machine)
git lfs install

# Tell Git LFS which file patterns to track (only needs to run once per repo)
git lfs track "*.zip"
git lfs track "*.wav"
git lfs track "*.exe"
git lfs track "*.dll"

# Stage .gitattributes if it changed
git add .gitattributes

# Stage all other changes
git add .

git commit -m "$Message"

# Find the latest tag like v1.2.3, sorted as version
$lastTag = git tag --list "v*" | Sort-Object {[version]($_ -replace '^v','')} -Descending | Select-Object -First 1

if ($lastTag -match '^v(\d+)\.(\d+)\.(\d+)$') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
} else {
    $major = 0; $minor = 0; $patch = 0
    $lastTag = "v0.0.0"
}

Write-Host "Last tag: $lastTag"
$choice = Read-Host "Which part would you like to increment? (1=major, 2=minor, 3=patch, default=patch):"
switch ($choice.ToLower()) {
    "major" { $major++; $minor=0; $patch=0 }
    "1"     { $major++; $minor=0; $patch=0 }
    "minor" { $minor++; $patch=0 }
    "2"     { $minor++; $patch=0 }
    "patch" { $patch++ }
    "3"     { $patch++ }
    default { $patch++ }
}

$newTag = "v$major.$minor.$patch"
Write-Host "Creating and pushing tag $newTag..."

git tag $newTag
git push
git push origin $newTag

Write-Host "Committed and tagged as $newTag."
