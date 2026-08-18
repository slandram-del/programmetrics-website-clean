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
    "studio-pricing.html",
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

$pricing = Read-RepoFile "pricing.html"
Add-Check ($pricing.Contains("Three distinct offers") -and $pricing.Contains("priced separately")) "Pricing model" "separate purchasing paths are explicit"

$oneTime = Read-RepoFile "one-time-analytics.html"
$approvedOneTimePrices = @('$49', '$79', '$199', '$299', '$499', '$799', '$1,500', '$3,500')
$oneTimeCatalogPages = @("one-time-analytics.html", "studio-pricing.html")
foreach ($page in $oneTimeCatalogPages) {
    $content = Read-RepoFile $page
    $tierCards = [regex]::Matches($content, '(?is)<article\b[^>]*data-one-time-tier[^>]*>.*?</article>')
    $priceTokens = $tierCards | ForEach-Object { ([regex]::Match($_.Value, '\$[0-9]+(?:,[0-9]{3})?(?:\.\d{2})?')).Value }
    Add-Check ($tierCards.Count -eq 8) "One-time catalog" "$page contains exactly eight tier cards"
    Add-Check ((Compare-Object $approvedOneTimePrices $priceTokens).Count -eq 0 -and $priceTokens.Count -eq 8) "One-time pricing" "$page contains exactly the eight approved prices"
    Add-Check (-not [regex]::IsMatch($content, '(?i)\b(?:Professional|Premium)\b')) "One-time pricing" "$page excludes retired nested output levels"
}

$pricingTierLine = [regex]::Match($pricing, '(?is)<strong>Essential Insights:\s*\$49.*?Future tiers:\s*(.*?)</strong>')
$pricingTierTokens = [regex]::Matches($pricingTierLine.Groups[1].Value, '\$[0-9]+(?:,[0-9]{3})?(?:\.\d{2})?') | ForEach-Object { $_.Value }
Add-Check ($pricingTierLine.Success -and (Compare-Object $approvedOneTimePrices[1..7] $pricingTierTokens).Count -eq 0 -and $pricingTierTokens.Count -eq 7 -and $pricing.Contains('Essential Insights: $49')) "Pricing overview" "lists the current $49 offer and seven future one-time prices"
Add-Check ($oneTime.Contains("does not create a recurring Studio subscription")) "One-time boundary" "does not imply subscription access"
Add-Check ($oneTime.Contains("Controlled-beta access only") -and $oneTime.Contains("not available for unrestricted public purchase")) "One-time availability" "controlled-beta and public-purchase boundaries are explicit"
$subscriptions = Read-RepoFile "studio-subscriptions.html"
Add-Check ($subscriptions.Contains("Studio Essentials") -and $subscriptions.Contains('$79/month') -and $subscriptions.Contains("5 analyses per month")) "Subscription pricing" 'Essentials is $79/month for 5 analyses'
Add-Check ($subscriptions.Contains("Studio Professional") -and $subscriptions.Contains('$179/month') -and $subscriptions.Contains("15 analyses per month")) "Subscription pricing" 'Professional is $179/month for 15 analyses'
Add-Check ($subscriptions.Contains("Studio Organization") -and $subscriptions.Contains('$349/month') -and $subscriptions.Contains("40 analyses per month")) "Subscription pricing" 'Organization is $349/month for 40 analyses'
Add-Check ($subscriptions.Contains("does not automatically include a one-time deliverable package")) "Subscription boundary" "one-time work is separate"
Add-Check (-not [regex]::IsMatch($subscriptions, '(?i)\bunlimited\b')) "Subscription boundary" "no unlimited plan language"
$subscriptionButtons = [regex]::Matches($subscriptions, '(?is)<button\b[^>]*>')
Add-Check ($subscriptionButtons.Count -eq 3) "Subscription checkout" "three plan controls are present"
foreach ($button in $subscriptionButtons) {
    Add-Check ([regex]::IsMatch($button.Value, '(?i)\bdisabled\b')) "Subscription checkout" "every plan checkout control is disabled"
}

$checkout = Read-RepoFile "checkout.html"
Add-Check ($checkout.Contains("Checkout unavailable") -and $checkout.Contains("coming soon")) "Checkout status" "unavailable state is explicit"
Add-Check ($checkout.Contains("Payment processing is not configured or active")) "Checkout status" "payment processing is inactive"
Add-Check (-not [regex]::IsMatch($checkout, '(?i)<script\b')) "Checkout controls" "no checkout or payment scripts load"
Add-Check (-not [regex]::IsMatch($checkout, '(?i)<(?:form|input|select)\b')) "Checkout controls" "no form, input, or selector can transact"
$checkoutButtons = [regex]::Matches($checkout, '(?is)<button\b[^>]*>')
Add-Check ($checkoutButtons.Count -gt 0) "Checkout controls" "disabled status controls are present"
foreach ($button in $checkoutButtons) {
    Add-Check ([regex]::IsMatch($button.Value, '(?i)\bdisabled\b')) "Checkout controls" "every checkout button is disabled"
}

$redirectPages = @("dashboard-generator.html", "tier-2-dashboard-builder.html")
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
Add-Check ($templates.Contains("Separate from analytics") -and $templates.Contains("will not include an Essential Insights analysis")) "Template boundary" "templates remain separate from analytics entitlements"
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
    Add-Check ($content.Contains("properly de-identified, structured data")) "De-identified-only policy" "$page states the canonical data rule"
    Add-Check ([regex]::IsMatch($content, '(?i)\b(?:unavailable|not active|coming soon|controlled beta|controlled-beta|unrestricted public)\b')) "Policy availability" "$page states an inactive-public or controlled-beta boundary"
}

$requiredIdentifierTerms = @(
    "Names", "street addresses", "email addresses", "phone numbers", "Social Security numbers",
    "medical-record numbers", "student-identification numbers", "full dates of birth",
    "payment-card or banking data", "passwords", "credentials", "authentication tokens",
    "security secrets", "identifiable health information", "FERPA-protected identifiable education records",
    "other legally restricted or regulated identifiable data"
)
foreach ($page in $corePolicyPages) {
    $content = Read-RepoFile $page
    foreach ($term in $requiredIdentifierTerms) {
        Add-Check ($content.IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0) "Prohibited identifiers" "$page prohibits $term"
    }
    Add-Check ($content.Contains("Open-ended narrative fields") -and $content.Contains("case notes") -and $content.Contains("comments") -and $content.Contains("free-text fields")) "Structured data only" "$page prohibits open-ended free text"
    Add-Check ($content.Contains("Removing names alone") -and $content.Contains("dates") -and $content.Contains("geographic information") -and $content.Contains("small groups") -and $content.Contains("rare characteristics") -and $content.Contains("combinations of fields")) "Indirect identification" "$page warns about indirect identification"
    Add-Check ($content.Contains("Anonymous record identifiers") -and $content.Contains("identify or contact an individual") -and $content.Contains("re-identification key") -and $content.Contains("must not provide that key")) "Anonymous identifiers" "$page keeps re-identification keys outside ProgramMetrics"
    Add-Check ($content.Contains("Customers must de-identify") -and $content.Contains("legal authority")) "Customer responsibility" "$page assigns de-identification and authority to customers"
    Add-Check ($content.Contains("does not perform legal de-identification") -and $content.Contains("HIPAA") -and $content.Contains("FERPA")) "No compliance guarantee" "$page disclaims legal de-identification and certification"
    Add-Check ([regex]::IsMatch($content, '(?i)browser-local.*does not eliminate (?:privacy|all privacy)')) "Browser-local boundary" "$page does not treat browser-local processing as risk elimination"
    Add-Check ([regex]::IsMatch($content, '(?i)(?:automated screening|checkbox).*(?:supplemental|does not replace|will not replace)')) "Supplemental screening" "$page does not treat screening as sufficient"
}
Add-Check ($security.Contains("Properly authorized workforce data") -and $security.Contains("contains none of the prohibited categories")) "Workforce data" "authorized workforce data excludes prohibited categories"
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
    Add-Check ($content.Contains("Effective July 30, 2026.")) "Interim policy" "$page has the effective date"
    Add-Check ($content.Contains("This interim policy applies only to the informational ProgramMetrics website, visitor email inquiries, beta tester applications, template feedback, and the current inactive product presentation.")) "Interim policy" "$page states its limited current scope"
    Add-Check ($content.Contains("This policy may be updated before checkout, uploads, paid services, or customer access are activated.")) "Interim policy" "$page reserves updates before service activation"
    Add-Check ([regex]::IsMatch($content, '(?i)checkout.*(?:unavailable|not active)') -and [regex]::IsMatch($content, '(?i)(?:file upload|uploads).*(?:unavailable|not active)') -and [regex]::IsMatch($content, '(?i)(?:paid outputs|paid services).*(?:unavailable|not active)') -and [regex]::IsMatch($content, '(?i)Studio access.*(?:unavailable|not active)')) "Interim availability" "$page keeps all customer capabilities inactive"
    Add-Check ([regex]::IsMatch($content, '(?i)identifiable health') -and $content.Contains("FERPA") -and [regex]::IsMatch($content, '(?i)payment-card') -and [regex]::IsMatch($content, '(?i)credential')) "Regulated data" "$page prohibits regulated data and credentials"
    foreach ($claim in $retiredLegalClaims.GetEnumerator()) {
        Add-Check (-not [regex]::IsMatch($content, $claim.Value)) "Retired legal claim" "$page excludes $($claim.Key)"
    }
}
Add-Check ((Read-RepoFile "refund-liability-policy.html").Contains("No current website payment exists to refund")) "Refund status" "no current website payment or active refund process exists"

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
Add-Check ((Read-RepoFile "privacy-policy.html").Contains("Template feedback is also processed by Formspree")) "Template feedback privacy" "privacy policy discloses the feedback processor and fields"

$betaApplication = Read-RepoFile "beta-testers.html"
$betaScript = Read-RepoFile "beta-testers.js"
Add-Check ($betaApplication.Contains('action="https://formspree.io/f/xlgqqdok"') -and $betaApplication.Contains('method="post"')) "Beta application" "uses the approved Formspree endpoint with POST"
Add-Check (-not [regex]::IsMatch($betaApplication, '(?i)<input\b[^>]*type="file"')) "Beta application" "does not accept file uploads"
foreach ($field in @("name", "email", "organizationType", "datasetSize", "dataType", "challenge", "feedbackAgreement", "dataAgreement", "termsAgreement")) {
    Add-Check ([regex]::IsMatch($betaApplication, "(?i)name=`"$([regex]::Escape($field))`"[^>]*\brequired\b")) "Beta application" "$field is required"
}
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
Add-Check (-not ($trackedFiles | Where-Object { [System.IO.Path]::GetExtension($_) -eq ".js" -and $_ -ne "beta-testers.js" })) "Public repository scope" "only the bounded beta-application script is tracked"
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
