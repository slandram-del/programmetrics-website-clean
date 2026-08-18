$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$checks = 0
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Template {
    param(
        [bool]$Condition,
        [string]$Message
    )

    $script:checks += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

$galleryPath = Join-Path $root "templates-workflow-apps.html"
$gallery = Get-Content -LiteralPath $galleryPath -Raw
$feedbackScript = Get-Content -LiteralPath (Join-Path $root "template-feedback.js") -Raw
$productPages = @(
    "program-evaluation-dashboard-template.html",
    "monthly-reporting-automation-template.html",
    "referral-service-tracker-template.html",
    "survey-reporting-template.html"
)

Assert-Template ($gallery.Contains("Starter workbook catalog")) "gallery identifies the Starter workbook catalog"
Assert-Template ($gallery.Contains("Downloads are not yet available")) "gallery keeps downloads unavailable"
Assert-Template ($gallery.Contains("customer access is currently unavailable")) "gallery keeps customer access unavailable"
Assert-Template ($gallery.Contains("Separate from analytics") -and $gallery.Contains("will not include an Essential Insights analysis")) "gallery separates templates from analytics entitlements"
Assert-Template (-not [regex]::IsMatch($gallery, '(?i)href="[^"]+\.xlsx(?:[?#][^"]*)?"')) "gallery exposes no direct workbook link"
Assert-Template ($gallery.Contains('id="template-feedback-form"') -and $gallery.Contains('action="https://formspree.io/f/xlgqqdok"') -and $gallery.Contains('method="post"')) "feedback form uses the approved Formspree endpoint"
Assert-Template (-not [regex]::IsMatch($gallery, '(?i)<input\b[^>]*type="file"')) "feedback form accepts no file upload"
foreach ($field in @("templateUsed", "experienceRating", "starterFeedback", "feedbackUseAgreement", "templateSafetyAgreement")) {
    Assert-Template ([regex]::IsMatch($gallery, "(?i)name=`"$([regex]::Escape($field))`"[^>]*\brequired\b")) "feedback form requires $field"
}
Assert-Template ($gallery.Contains('name="_gotcha"') -and $gallery.Contains('tabindex="-1"')) "feedback form includes a honeypot"
Assert-Template ($gallery.Contains("Do not paste spreadsheet data") -and $gallery.Contains("does not provide a download, purchase, analysis, or customer account")) "feedback form states its data and capability boundaries"
Assert-Template ($feedbackScript.Contains('headers: { Accept: "application/json" }') -and $feedbackScript.Contains('if (!response.ok)')) "feedback script handles Formspree responses"
Assert-Template ($feedbackScript.Contains("emailInput.value.trim()") -and $feedbackScript.Contains("!followUpConsent.checked")) "feedback script requires consent for optional email follow-up"
Assert-Template ($feedbackScript.Contains("form.reset()") -and $feedbackScript.Contains("successMessage.hidden = false")) "feedback script resets after success"
Assert-Template ($feedbackScript.Contains("hello@programmetrics.io") -and $feedbackScript.Contains("without attaching files")) "feedback script provides a bounded fallback"

foreach ($page in $productPages) {
    $path = Join-Path $root $page
    Assert-Template (Test-Path -LiteralPath $path -PathType Leaf) "$page exists"
    $content = Get-Content -LiteralPath $path -Raw
    Assert-Template ([regex]::IsMatch($content, '(?i)<button[^>]+disabled[^>]+aria-disabled="true"')) "$page disables its download control"
    Assert-Template ($content.Contains("Downloads not yet available")) "$page states that downloads are unavailable"
    Assert-Template ([regex]::IsMatch($content, '(?i)paid Pro edition.*price.*license.*fulfillment.*updates?.*support')) "$page identifies unresolved Pro release decisions"
    Assert-Template (-not [regex]::IsMatch($content, '(?i)href="[^"]+\.xlsx(?:[?#][^"]*)?"')) "$page exposes no direct workbook link"
    Assert-Template (-not [regex]::IsMatch($content, '(?i)mailto:[^"]*(?:buy|purchase|order)')) "$page exposes no purchase email shortcut"
}

$trackedWorkbooks = @(& git -C $root ls-files "*.xlsx")
Assert-Template ($LASTEXITCODE -eq 0) "tracked-file inventory is available"
Assert-Template ($trackedWorkbooks.Count -eq 0) "public repository tracks no workbook binaries"

$workingWorkbooks = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.xlsx" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })
Assert-Template ($workingWorkbooks.Count -eq 0) "public website worktree contains no workbook binaries"

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error "FAILED: $failure" -ErrorAction Continue
    }
    Write-Output "Template distribution checks failed: $($failures.Count) of $checks"
    exit 1
}

Write-Output "Template distribution checks passed: $checks"
