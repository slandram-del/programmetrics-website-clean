$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()
$passes = [System.Collections.Generic.List[string]]::new()

function Add-Check {
    param([bool]$Condition, [string]$Name, [string]$Detail)
    if ($Condition) {
        $passes.Add("$Name - $Detail")
    } else {
        $failures.Add("$Name - $Detail")
    }
}

function Read-RepoFile {
    param([string]$RelativePath)
    return [System.IO.File]::ReadAllText((Join-Path $repoRoot $RelativePath))
}

$modelPages = @(
    "index.html",
    "pricing.html",
    "one-time-analytics.html",
    "studio-subscriptions.html",
    "templates-workflow-apps.html",
    "security-data-use.html"
)

$navigatedPages = @(
    "checkout.html",
    "contact.html",
    "index.html",
    "monthly-reporting-automation-template.html",
    "one-time-analytics.html",
    "pricing.html",
    "privacy-policy.html",
    "program-evaluation-dashboard-template.html",
    "program-evaluation-demo.html",
    "referral-service-tracker-template.html",
    "refund-liability-policy.html",
    "security-data-use.html",
    "studio.html",
    "beta-testers.html",
    "studio-subscriptions.html",
    "survey-reporting-template.html",
    "templates-workflow-apps.html",
    "terms-of-service.html"
)

$publicPages = $navigatedPages + @(
    "dashboard-generator.html",
    "tier-2-dashboard-builder.html"
) | Select-Object -Unique

$navTargets = @(
    'href="index.html#top">Home',
    'href="pricing.html">Pricing',
    'href="one-time-analytics.html">One-Time Analytics',
    'href="studio-subscriptions.html">Studio Subscriptions',
    'href="templates-workflow-apps.html">Templates &amp; Workflow Apps',
    'href="security-data-use.html">Security &amp; Data Use',
    'href="contact.html">Contact'
)

foreach ($page in $modelPages) {
    Add-Check (Test-Path -LiteralPath (Join-Path $repoRoot $page)) "Required surface" $page
}

foreach ($page in $navigatedPages) {
    $content = Read-RepoFile $page
    foreach ($target in $navTargets) {
        Add-Check ($content.Contains($target)) "Shared navigation" "$page contains $target"
    }
}

foreach ($page in $publicPages) {
    $content = Read-RepoFile $page
    $emailLinks = [regex]::Matches($content, 'href="mailto:([^?"]+)')
    foreach ($emailLink in $emailLinks) {
        Add-Check ($emailLink.Groups[1].Value -eq "hello@programmetrics.io") "Public contact" "$page uses hello@programmetrics.io"
    }
    Add-Check (-not [regex]::IsMatch($content, '(?i)href="(?:\./)?license\.html(?:[?#][^"]*)?"')) "Draft license link" "$page does not expose the placeholder license route"
    Add-Check (-not [regex]::IsMatch($content, '(?i)\b(?:prelaunch draft|attorney review|attorney approval|attorney[- ]approved|approved by (?:an )?attorney|attorney-reviewed terms)\b')) "Interim policy status" "$page has no draft label or attorney claim"
}

$claimFiles = @(
    "index.html",
    "pricing.html",
    "one-time-analytics.html",
    "studio-subscriptions.html",
    "templates-workflow-apps.html",
    "security-data-use.html",
    "studio-pricing.html",
    "contact.html",
    "checkout.html",
    "dashboard-generator.html",
    "tier-2-dashboard-builder.html"
)

$prohibitedClaims = [ordered]@{
    "free analysis" = '(?i)\bfree[- ]analysis\b'
    "free preview" = '(?i)\bfree preview\b'
    "consulting positioning" = '(?i)\bconsulting[- ](?:quality|grade)\b'
    "unsupported-format promise" = '(?i)\b(?:any|all|every)\s+(?:spreadsheet|file|format)s?\b'
    "unlimited use" = '(?i)\bunlimited[- ]use\b'
    "unlimited exports" = '(?i)\bunlimited export(?:s| formats)?\b'
    "unsupported format language" = '(?i)\bunsupported[- ]format\b'
}

foreach ($file in $claimFiles) {
    $content = Read-RepoFile $file
    foreach ($claim in $prohibitedClaims.GetEnumerator()) {
        Add-Check (-not [regex]::IsMatch($content, $claim.Value)) "Prohibited claim" "$file excludes $($claim.Key)"
    }
}

$homepageContent = Read-RepoFile "index.html"
Add-Check ($homepageContent.Contains("One-Time Analytics") -and $homepageContent.Contains("Studio Subscriptions") -and $homepageContent.Contains("Templates &amp; Workflow Apps")) "Homepage model" "all three offers are distinct"
Add-Check ($homepageContent.Contains("Essential Insights") -and $homepageContent.Contains("controlled beta") -and $homepageContent.Contains("unrestricted public checkout is not yet available")) "Homepage availability" "controlled beta and public-checkout boundary are explicit"
Add-Check (-not [regex]::IsMatch($homepageContent, '(?i)\b(?:purchase a fixed package|use the private Studio workspace|choose a Studio subscription|choose a template or workflow app)\b')) "Homepage availability" "no current purchase or access claims"


# Only the Essential Insights launch price may be published. Include older routes
# and nested pages so an unlinked catalog cannot bypass this check.
$publicHtml = @(& git -C $repoRoot ls-files -- '*.html')
Add-Check ($LASTEXITCODE -eq 0 -and $publicHtml.Count -gt 0) "Pricing scan" "public HTML inventory is available"
foreach ($page in $publicHtml) {
    $content = [Net.WebUtility]::HtmlDecode((Read-RepoFile $page))
    $offScopePrice = @([regex]::Matches($content, '\$\s*\d[\d,]*(?:\.\d+)?') |
        Where-Object { $_.Value -notmatch '^\$\s*49(?:\.00)?$' })
    Add-Check ($offScopePrice.Count -eq 0) "Public pricing" "$page contains only the approved dollar amount"
    Add-Check ($content -notmatch '(?i)>\s*(?:Data Readiness Check|Decision Package|Dashboard Summary|Trend Analysis|Leadership Report|Core Metrics Report)\s*</h[1-6]>') "Public catalog" "$page excludes retired product offers"
    Add-Check ($content -notmatch '(?i)\$\s*49(?:\.00)?\s*(?:/\s*(?:mo|month|year)|per\s+(?:month|year)|monthly|annually)') "Purchase unit" "$page excludes recurring pricing"
    Add-Check ($content -notmatch '(?i)(?:href|src|action)\s*=\s*["''](?:https?:)?//(?:checkout\.stripe\.com|buy\.stripe\.com|js\.stripe\.com|(?:www\.)?paypal\.(?:com|me))\b') "Public payments" "$page exposes no payment provider link, script or form"
}

$pricing = Read-RepoFile "pricing.html"
$oneTime = Read-RepoFile "one-time-analytics.html"
$tierCards = [regex]::Matches($oneTime, '(?is)<article\b[^>]*data-one-time-tier[^>]*>.*?</article>')
Add-Check ($tierCards.Count -eq 1 -and $tierCards[0].Value.Contains("Essential Insights") -and $tierCards[0].Value.Contains('$49 per analysis order')) "One-time catalog" "one named Essential Insights order at the approved price"
Add-Check ($pricing.Contains("One-Time Analytics") -and $pricing.Contains("Studio Subscriptions") -and $pricing.Contains("Templates &amp; Workflow Apps")) "Pricing model" "one-time analysis, subscriptions and separately licensed templates remain distinct"
Add-Check ($pricing.Contains('$49 per analysis order') -and $pricing.Contains("Enrollment is closed")) "Pricing overview" "launch price and enrollment status are explicit"
Add-Check ($oneTime.Contains("Beta enrollment is closed") -and $oneTime.Contains("no-charge invitation") -and $oneTime.Contains("fictional CSV")) "One-time availability" "closed beta and no-charge synthetic testing are explicit"
$subscriptions = Read-RepoFile "studio-subscriptions.html"
Add-Check ($subscriptions.Contains("No subscription is implied by an Essential Insights order")) "Subscription boundary" "separate product"
Add-Check ($subscriptions.Contains("No Studio subscription plan is currently available for purchase or activation")) "Subscription status" "purchase and activation are closed"
Add-Check ($subscriptions -notmatch '(?i)\b(?:unlimited|Studio Essentials|Studio Professional|Studio Organization|\d+ analyses per month)\b') "Subscription positioning" "withholds unverified names and plan allowances"
$subscriptionButtons = [regex]::Matches($subscriptions, '(?is)<button\b[^>]*>')
Add-Check ($subscriptionButtons.Count -gt 0) "Subscription checkout" "unavailable control is present"
foreach ($button in $subscriptionButtons) {
    Add-Check ($button.Value -match '(?i)\sdisabled(?:\s|=|>)') "Subscription checkout" "every checkout button is disabled"
}

$checkout = Read-RepoFile "checkout.html"
Add-Check ($checkout.Contains("Public checkout unavailable")) "Checkout status" "unavailable state is explicit"
Add-Check ($checkout.Contains("not accepting live public payments")) "Checkout status" "payment processing is inactive"
Add-Check (-not [regex]::IsMatch($checkout, '(?i)<script\b')) "Checkout controls" "no checkout or payment scripts load"
Add-Check (-not [regex]::IsMatch($checkout, '(?i)<(?:form|input|select)\b')) "Checkout controls" "no form, input, or selector can transact"
$checkoutButtons = [regex]::Matches($checkout, '(?is)<button\b[^>]*>')
Add-Check ($checkoutButtons.Count -gt 0) "Checkout controls" "disabled status controls are present"
foreach ($button in $checkoutButtons) {
    Add-Check ([regex]::IsMatch($button.Value, '(?i)\bdisabled\b')) "Checkout controls" "every checkout button is disabled"
}

$redirectPages = @("dashboard-generator.html", "tier-2-dashboard-builder.html", "studio-pricing.html")
foreach ($redirectPage in $redirectPages) {
    $redirect = Read-RepoFile $redirectPage
    Add-Check ($redirect.Contains('<meta http-equiv="refresh" content="0; url=one-time-analytics.html">')) "Legacy redirect" "$redirectPage has fixed meta redirect"
    Add-Check ($redirect.Contains('window.location.replace("one-time-analytics.html")')) "Legacy redirect" "$redirectPage has fixed JavaScript redirect"
    Add-Check ($redirect.Contains('<link rel="canonical" href="one-time-analytics.html">')) "Legacy redirect" "$redirectPage has canonical target"
    Add-Check (-not [regex]::IsMatch($redirect, '(?i)(?:location\.search|URLSearchParams|one-time-analytics\.html\?)')) "Legacy redirect" "$redirectPage discards query parameters"
}

$legalRedirects = [ordered]@{
    "terms.html" = "terms-of-service.html"
    "privacy.html" = "privacy-policy.html"
    "license.html" = "terms-of-service.html"
    "terms/index.html" = "../terms-of-service.html"
    "privacy/index.html" = "../privacy-policy.html"
    "license/index.html" = "../terms-of-service.html"
}
foreach ($redirectEntry in $legalRedirects.GetEnumerator()) {
    $redirect = Read-RepoFile $redirectEntry.Key
    $target = $redirectEntry.Value
    Add-Check ($redirect.Contains("<meta http-equiv=`"refresh`" content=`"0; url=$target`">")) "Legal redirect" "$($redirectEntry.Key) redirects to $target"
    Add-Check ($redirect.Contains("window.location.replace(`"$target`")")) "Legal redirect" "$($redirectEntry.Key) has a JavaScript redirect"
    Add-Check ($redirect.Contains("<link rel=`"canonical`" href=`"$target`">")) "Legal redirect" "$($redirectEntry.Key) has the correct canonical target"
    Add-Check (-not $redirect.Contains("TODO: Legal review required")) "Legal redirect" "$($redirectEntry.Key) contains no legal-review placeholder"
}

$templates = Read-RepoFile "templates-workflow-apps.html"
Add-Check ($templates.Contains("will not include an Essential Insights analysis")) "Template boundary" "templates remain separate from analytics entitlements"
Add-Check ($templates.Contains("Named compatibility")) "Template boundary" "compatibility is offer-specific"
Add-Check ($templates.Contains("Downloads are not yet available") -and $templates.Contains("currently unavailable")) "Template availability" "downloads and customer access are unavailable"
Add-Check (-not [regex]::IsMatch($templates, '(?i)\b(?:the purchased item|before purchase)\b')) "Template availability" "no current-purchase wording"

$security = Read-RepoFile "security-data-use.html"
$corePolicyPages = @("security-data-use.html", "privacy-policy.html", "terms-of-service.html")
$alignedPolicyPages = @(
    "index.html", "contact.html", "one-time-analytics.html", "pricing.html",
    "privacy-policy.html", "program-evaluation-demo.html", "refund-liability-policy.html",
    "security-data-use.html", "studio-subscriptions.html", "studio.html", "terms-of-service.html"
)
foreach ($page in $alignedPolicyPages) {
    $content = Read-RepoFile $page
    Add-Check (($content -match '(?i)properly de-identified(?:,? structured data| UTF-8 CSV)')) "De-identified-only policy" "$page states the canonical data rule"
    Add-Check ([regex]::IsMatch($content, '(?i)\b(?:unavailable|not active|coming soon|controlled beta|controlled-beta|unrestricted public)\b')) "Policy availability" "$page states an inactive-public or controlled-beta boundary"
}


# These policy pages describe the same boundaries using plain-language variants.
# Require each category independently so omission of one category fails the suite.
$identifierPatterns = @(
    'names', 'street (?:or full mailing )?addresses', 'email addresses', '(?:tele)?phone numbers',
    'Social Security numbers', 'medical-record (?:or patient )?numbers', 'student (?:or government )?identification numbers',
    'full dates of birth', 'payment-card', '(?:banking data|financial-account)', 'passwords', 'credentials',
    'authentication tokens', 'security secrets', 'identifiable health information',
    'FERPA-protected identifiable education records', 'other legally restricted identifiable data'
)
foreach ($page in $corePolicyPages) {
    $content = Read-RepoFile $page
    foreach ($pattern in $identifierPatterns) {
        Add-Check ($content -match $pattern) "Prohibited identifiers" "$page includes $pattern"
    }
    Add-Check ($content -match '(?i)open-ended case notes[^<]*narratives[^<]*comments[^<]*free-text fields[^<]*prohibited') "Structured data only" "$page excludes risky free text"
    Add-Check ($content -match '(?i)Removing names alone[^<]*dates[^<]*geographic information[^<]*small groups[^<]*rare characteristics[^<]*combinations of fields') "Indirect identification" "$page describes combinations that may identify someone"
    Add-Check ($content -match '(?i)Anonymous record identifiers[^<]*only when ProgramMetrics cannot use them to identify or contact' -and $content -match '(?i)(must|must keep)[^<]*re-identification key outside ProgramMetrics') "Anonymous identifiers" "$page keeps identifying keys outside the service"
    Add-Check ($content -match '(?i)(?:Customers (?:are|remain) responsible[^<]*(?:authority|authorization)[^<]*de-identification|Customers must have authority[^<]*remove prohibited information|You may use only data that you are legally authorized[^<]*properly de-identified)') "Customer responsibility" "$page requires both authorization and de-identification"
    Add-Check ($content -notmatch '(?i)\b(?:is|are) (?:HIPAA|FERPA)[ -](?:compliant|certified)\b') "No compliance guarantee" "$page makes no HIPAA/FERPA certification claim"
    Add-Check ($content -match '(?i)does not (?:certify legal de-identification or compliance|perform legal de-identification|prove legal de-identification[^<]*certify compliance)') "No compliance guarantee" "$page limits de-identification and compliance claims"
    Add-Check ($content -match '(?i)Browser-local processing[^<]*does not eliminate privacy') "Browser-local boundary" "$page explains residual privacy risk"
    Add-Check ($content -match '(?i)Automated screening[^<]*(?:supplemental|may not detect)' -and $content -match '(?i)(?:does not certify legal de-identification|does not prove legal de-identification)') "Supplemental screening" "$page describes limits of screening"
}
Add-Check ($security.Contains("general product restriction applies to all program and workforce data") -and $security.Contains("remove prohibited information")) "Workforce data" "workforce data has no exception"

Add-Check (-not [regex]::IsMatch($security, '(?i)\bunless a separate written agreement\b')) "Security prohibited data" "no separate-agreement exception"
$legalPages = @("terms-of-service.html", "privacy-policy.html", "refund-liability-policy.html")
$retiredLegalClaims = [ordered]@{
    "upgrade calculations" = '(?i)\b(?:upgrade charge|paying the difference|desired higher output level)\b'
    "unlocked Studio levels" = '(?i)\b(?:unlocked Studio level|unlock(?:s|ed)? (?:the )?(?:corresponding )?Studio)\b'
    "paid access tokens" = '(?i)\bpaid access token(?:s)?\b'
    "uploaded-data package previews" = '(?i)\bpreview higher packages with uploaded data\b'
    "custom setup or work" = '(?i)\bcustom (?:setup|work)\b'
}
foreach ($page in $legalPages) {
    $content = Read-RepoFile $page
    Add-Check ($content -match 'Effective [A-Z][a-z]+ [0-9]{1,2}, [0-9]{4}\.') "Policy date" "$page identifies its effective date"
    Add-Check ($content.Contains("Essential Insights") -and $content -match 'invite-only' -and $content.Contains("controlled beta")) "Policy scope" "$page addresses the invitation-only beta"
    Add-Check ($content -match '(?i)(?:Material changes will be reflected by a new effective date|Before ProgramMetrics accepts real payments, the applicable customer terms will state)') "Policy updates" "$page specifies changes before new use or real payments"
    Add-Check ($content -match '(?i)Public live checkout[^<]*(?:not available|unavailable)' -and $content -match '(?i)(?:No real payment is processed|does not process a real payment)') "Payment boundary" "$page limits checkout to test transactions"
    Add-Check ($content -match '(?i)identifiable (?:health|regulated) (?:information|data)' -and $content.Contains("FERPA") -and $content -match '(?i)(?:payment-card|financial-account)' -and $content -match '(?i)credential') "Regulated data" "$page prohibits regulated data and credentials"
    foreach ($claim in $retiredLegalClaims.GetEnumerator()) {
        Add-Check (-not [regex]::IsMatch($content, $claim.Value)) "Retired legal claim" "$page excludes $($claim.Key)"
    }
}
Add-Check ((Read-RepoFile "refund-liability-policy.html").Contains("no real customer charge to refund")) "Refund status" "no current website payment or active refund process exists"

$contact = Read-RepoFile "contact.html"
Add-Check ($contact.Contains("English-only")) "Contact language" "contact page is explicitly English-only"
Add-Check (-not [regex]::IsMatch($contact, '(?i)(?:google_translate|translate\.google|data-translate-lang|language-widget|<script\b)')) "Contact language" "translation controls and scripts are absent"
Add-Check ($contact.Contains("One-Time Analytics") -and $contact.Contains("Studio Subscriptions") -and $contact.Contains("Templates &amp; Workflow Apps")) "Contact model" "three product lines are explicit"
Add-Check ($contact.Contains("currently unavailable")) "Contact availability" "inactive capabilities are explicit"

$templateGallery = Read-RepoFile "templates-workflow-apps.html"
$templateFeedbackScript = Read-RepoFile "template-feedback.js"
Add-Check ($templateGallery.Contains('id="template-feedback-form"') -and $templateGallery.Contains('action="https://formspree.io/f/xlgqqdok"') -and $templateGallery.Contains('method="post"')) "Template feedback" "uses the approved Formspree endpoint with POST"
Add-Check (-not [regex]::IsMatch($templateGallery, '(?i)<input\b[^>]*type="file"')) "Template feedback" "does not accept file uploads"
foreach ($field in @("templateUsed", "experienceRating", "starterFeedback", "feedbackUseAgreement", "templateSafetyAgreement")) {
    Add-Check ([regex]::IsMatch($templateGallery, "(?i)name=`"$([regex]::Escape($field))`"[^>]*\brequired\b")) "Template feedback" "$field is required"
}
Add-Check ($templateGallery.Contains('name="_gotcha"') -and $templateGallery.Contains('tabindex="-1"')) "Template feedback" "honeypot field is present"
Add-Check ($templateGallery.Contains("Do not paste spreadsheet data") -and $templateGallery.Contains("does not provide a download, purchase, analysis, or customer account")) "Template feedback" "data and capability boundaries are explicit"
Add-Check ($templateFeedbackScript.Contains('headers: { Accept: "application/json" }') -and $templateFeedbackScript.Contains('if (!response.ok)')) "Template feedback submission" "requests JSON and handles non-success responses"
Add-Check ($templateFeedbackScript.Contains("emailInput.value.trim()") -and $templateFeedbackScript.Contains("!followUpConsent.checked")) "Template feedback submission" "requires consent before optional email follow-up"
Add-Check ($templateFeedbackScript.Contains("form.reset()") -and $templateFeedbackScript.Contains("successMessage.hidden = false")) "Template feedback submission" "resets the form and presents confirmation after success"
Add-Check ($templateFeedbackScript.Contains("hello@programmetrics.io") -and $templateFeedbackScript.Contains("without attaching files")) "Template feedback submission" "shows a bounded fallback after failure"
Add-Check (((Read-RepoFile "privacy-policy.html") -match '(?i)Template feedback:</strong> Formspree processes[^<]*experience rating[^<]*email[^<]*consent')) "Template feedback privacy" "privacy policy discloses the feedback processor and fields"

$betaApplication = Read-RepoFile "beta-testers.html"
$betaScript = Read-RepoFile "beta-testers.js"
Add-Check ($betaApplication.Contains('action="https://formspree.io/f/xlgqqdok"') -and $betaApplication.Contains('method="post"')) "Beta application" "uses the approved Formspree endpoint with POST"
Add-Check (-not [regex]::IsMatch($betaApplication, '(?i)<input\b[^>]*type="file"')) "Beta application" "does not accept file uploads"
foreach ($field in @("name", "email", "organizationType", "datasetSize", "dataType", "challenge", "feedbackAgreement", "dataAgreement", "termsAgreement")) {
    Add-Check ([regex]::IsMatch($betaApplication, "(?i)name=`"$([regex]::Escape($field))`"[^>]*\brequired\b")) "Beta application" "$field is required"
}
Add-Check ($betaApplication -notmatch '(?i)<textarea\b' -and $betaApplication.Contains('<select name="dataType" required>') -and $betaApplication.Contains('<select name="challenge" required>')) "Beta interest" "uses bounded reporting choices"
Add-Check ($betaApplication.Contains("only the fictional sample provided by ProgramMetrics") -and $betaApplication.Contains("requires an invitation") -and $betaApplication.Contains("testers pay nothing")) "Beta interest" "states test-data, admission and payment boundaries"
Add-Check ($betaApplication.Contains('name="_gotcha"') -and $betaApplication.Contains('tabindex="-1"')) "Beta application" "honeypot field is present"
Add-Check (-not [regex]::IsMatch($betaApplication, '(?i)<script\b(?![^>]*src="beta-testers\.js)')) "Beta application" "loads no unexpected scripts"
Add-Check ($betaScript.Contains('headers: { Accept: "application/json" }') -and $betaScript.Contains('if (!response.ok)')) "Beta submission" "requests JSON and handles non-success responses"
Add-Check ($betaScript.Contains('selectedFeatures.length === 0') -and $betaScript.Contains('Please select at least one feature')) "Beta submission" "requires at least one feature selection"
Add-Check ($betaScript.Contains('form.reset()') -and $betaScript.Contains('successMessage.hidden = false')) "Beta submission" "resets the form and presents confirmation after success"
Add-Check ($betaScript.Contains('errorMessage.hidden = false') -and $betaScript.Contains('hello@programmetrics.io')) "Beta submission" "shows a bounded support fallback after failure"

$availabilityPages = @("index.html", "contact.html", "one-time-analytics.html", "pricing.html", "privacy-policy.html", "program-evaluation-demo.html", "refund-liability-policy.html", "security-data-use.html", "studio-pricing.html", "studio-subscriptions.html", "studio.html", "terms-of-service.html")
$activeCapabilityClaims = [ordered]@{
    "active purchase" = '(?i)\b(?:buy now|purchase now|complete (?:your )?purchase)\b'
    "active upload" = '(?i)\b(?:upload (?:your|a) file|submit your data)\b'
    "active paid generation" = '(?i)\b(?:generate (?:your )?(?:paid )?(?:report|output)|download your results)\b'
    "active Studio activation" = '(?i)\b(?:activate Studio|open workspace)\b'
}
foreach ($page in $availabilityPages) {
    $content = Read-RepoFile $page
    foreach ($claim in $activeCapabilityClaims.GetEnumerator()) {
        Add-Check (-not [regex]::IsMatch($content, $claim.Value)) "Inactive capability" "$page excludes $($claim.Key) claims"
    }
}

$linkPages = $modelPages + @("contact.html", "studio.html", "studio-pricing.html")
foreach ($page in $linkPages) {
    $content = Read-RepoFile $page
    $matches = [regex]::Matches($content, 'href="([^"]+)"')
    foreach ($match in $matches) {
        $href = $match.Groups[1].Value
        if ($href -match '^(?:https?:|mailto:|#|javascript:)') { continue }
        $pathOnly = ($href -split '[?#]')[0]
        if ([string]::IsNullOrWhiteSpace($pathOnly)) { continue }
        $target = Join-Path $repoRoot $pathOnly
        Add-Check (Test-Path -LiteralPath $target) "Local link" "$page -> $pathOnly"
    }
}

$trackedFiles = @(& git -C $repoRoot ls-files)
Add-Check ($LASTEXITCODE -eq 0) "Public repository scope" "tracked-file inventory is available"
Add-Check (-not ($trackedFiles | Where-Object { $_ -match '^(?:docs|src)/' })) "Public repository scope" "internal documentation and application-source directories are not tracked"
Add-Check (-not ($trackedFiles | Where-Object { [System.IO.Path]::GetExtension($_) -eq ".js" -and $_ -notin @("beta-testers.js", "template-feedback.js") })) "Public repository scope" "only the reviewed beta and template form scripts are tracked"
Add-Check (-not ($trackedFiles | Where-Object { $_ -match '(?i)^images/.*(?:screenshot|chatbot|prompt).*\.(?:png|jpe?g|webp)$' })) "Public repository scope" "internal working screenshots are not tracked"
$corruptionScan = ($claimFiles + @("checkout.html", "terms-of-service.html")) | Select-Object -Unique
foreach ($file in $corruptionScan) {
    $content = Read-RepoFile $file
    Add-Check (-not [regex]::IsMatch($content, '(?i)\b(?:ppload|eenerate|UcustomU|creckout|croose|trey)\b')) "Text integrity" $file
}

Write-Host "PASS: $($passes.Count)"
foreach ($pass in $passes) { Write-Host "  $pass" }

if ($failures.Count -gt 0) {
    Write-Host "FAIL: $($failures.Count)"
    foreach ($failure in $failures) { Write-Host "  $failure" }
    exit 1
}

Write-Host "FAIL: 0"
exit 0
