$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $Root "site.config.json"
$Config = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$BaseUrl = $Config.siteUrl
$BusinessName = $Config.businessName
$PhoneDisplay = $Config.contact.phoneDisplay
$PhoneHref = $Config.contact.phoneHref
$PhoneSchema = $PhoneHref -replace "^tel:", ""
$WhatsappUrl = $Config.contact.whatsappUrl
$WhatsappMessage = $Config.contact.whatsappMessage
$WhatsappHref = if ([string]::IsNullOrWhiteSpace($WhatsappMessage)) { $WhatsappUrl } else { "$WhatsappUrl`?text=$([System.Uri]::EscapeDataString($WhatsappMessage))" }
$ServiceAreaText = $Config.serviceAreas.summary
$ConfiguredServices = @($Config.services)
$Pages = New-Object System.Collections.Generic.List[string]

function HtmlEncode([string]$Value) {
  return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Get-UrlPath([string]$OutFile) {
  $rel = ($OutFile -replace "\\", "/")
  if ($rel -eq "index.html") { return "/" }
  if ($rel.EndsWith("/index.html")) { return "/" + $rel.Substring(0, $rel.Length - "/index.html".Length) + "/" }
  return "/" + $rel
}

function Get-Prefix([string]$OutFile) {
  $dir = Split-Path $OutFile -Parent
  if ([string]::IsNullOrWhiteSpace($dir) -or $dir -eq ".") { return "" }
  $depth = ($dir -split "[\\/]").Count
  return "../" * $depth
}

function Write-TextFile([string]$OutFile, [string]$Content) {
  $full = Join-Path $Root $OutFile
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $utf8 = New-Object System.Text.UTF8Encoding $false
  if ($OutFile -eq "robots.txt" -and (Test-Path $full)) { return }
  if (Test-Path $full) {
    $existing = [System.IO.File]::ReadAllText($full, $utf8)
    if ($existing -eq $Content) { return }
  }
  [System.IO.File]::WriteAllText($full, $Content, $utf8)
}

function JsonLd([object]$Object) {
  $json = $Object | ConvertTo-Json -Depth 12 -Compress
  return "<script type=""application/ld+json"">$json</script>"
}

function BreadcrumbSchema([string]$Title, [string]$Canonical) {
  return [ordered]@{
    "@context" = "https://schema.org"
    "@type" = "BreadcrumbList"
    itemListElement = @(
      [ordered]@{ "@type" = "ListItem"; position = 1; name = "דף הבית"; item = "$BaseUrl/" },
      [ordered]@{ "@type" = "ListItem"; position = 2; name = $Title; item = $Canonical }
    )
  }
}

function FaqSchema([array]$Faqs) {
  return [ordered]@{
    "@context" = "https://schema.org"
    "@type" = "FAQPage"
    mainEntity = @($Faqs | ForEach-Object {
      [ordered]@{
        "@type" = "Question"
        name = $_[0]
        acceptedAnswer = [ordered]@{ "@type" = "Answer"; text = $_[1] }
      }
    })
  }
}

function Get-ServiceHref([object]$Service, [string]$Prefix) {
  if ([string]::IsNullOrWhiteSpace($Service.url)) { return "${Prefix}contact/" }
  return "$Prefix$($Service.url)"
}

function FooterServiceLinksHtml([string]$Prefix) {
  $html = ""
  foreach ($service in $ConfiguredServices) {
    $html += "        <a href=""$(Get-ServiceHref $service $Prefix)"">$(HtmlEncode $service.name)</a>`n"
  }
  return $html.TrimEnd()
}

function HeaderHtml([string]$Prefix, [bool]$Landing) {
  $homeHref = if ($Prefix -eq "") { "index.html" } else { $Prefix }
  $nav = ""
  if (-not $Landing) {
    $nav = @"
      <nav class="site-nav" id="site-nav" aria-label="ניווט ראשי">
        <a href="${homeHref}#services">שירותים</a>
        <a href="${Prefix}azorei-sherut/">אזורי שירות</a>
        <a href="${Prefix}blog/">מדריכים</a>
        <a href="${Prefix}contact/">צור קשר</a>
      </nav>
"@
  }

  return @"
  <header class="site-header">
    <div class="container header-inner">
      <a class="brand" href="$homeHref" aria-label="חזרה לדף הבית">
        <span class="brand-mark">מ</span>
        <span data-business-name>$BusinessName</span>
      </a>
      $nav
      <div class="header-actions">
        <a class="btn btn-green" href="$WhatsappHref" data-whatsapp>וואטסאפ מהיר</a>
        <a class="btn btn-primary" href="$PhoneHref" data-call>התקשרו</a>
        <button class="menu-toggle" type="button" data-menu-toggle aria-controls="site-nav" aria-expanded="false" aria-label="פתיחת תפריט">
          <span></span><span></span><span></span>
        </button>
      </div>
    </div>
  </header>
"@
}

function FooterHtml([string]$Prefix, [bool]$Landing) {
  $footerServiceLinks = FooterServiceLinksHtml $Prefix
  if ($Landing) {
    return @"
  <footer class="site-footer">
    <div class="container footer-bottom">
      <strong data-business-name>$BusinessName</strong> | טלפון: <span data-phone-text>$PhoneDisplay</span> | המחיר הסופי משתנה לפי פרטי ההובלה בפועל.
    </div>
  </footer>
"@
  }

  return @"
  <footer class="site-footer">
    <div class="container footer-grid">
      <div>
        <h2 data-business-name>$BusinessName</h2>
        <p>הובלות קטנות וגדולות במרכז, בשפלה ובירושלים, עם שירות אישי, הצעת מחיר ברורה ושמירה על הציוד.</p>
        <p>טלפון: <a href="$PhoneHref" data-call data-phone-text>$PhoneDisplay</a></p>
      </div>
      <div>
        <h3>שירותים</h3>
$footerServiceLinks
      </div>
      <div>
        <h3>מידע שימושי</h3>
        <a href="${Prefix}mehiron-hovalot/">בדיקת מחיר</a>
        <a href="${Prefix}azorei-sherut/">אזורי שירות</a>
        <a href="${Prefix}blog/">מדריכים</a>
        <a href="${Prefix}privacy/">מדיניות פרטיות</a>
      </div>
      <div>
        <h3>יצירת קשר</h3>
        <a href="$WhatsappHref" data-whatsapp>שליחת וואטסאפ</a>
        <a href="$PhoneHref" data-call>התקשר עכשיו</a>
        <a href="${Prefix}contact/">טופס הצעת מחיר</a>
      </div>
    </div>
    <div class="container footer-bottom">
      אזורי שירות: $ServiceAreaText להצעת מחיר מדויקת שלחו פרטים ותמונות בוואטסאפ.
    </div>
  </footer>
"@
}

function LeadFormHtml([bool]$Compact) {
  $itemsClass = if ($Compact) { "field full" } else { "field full" }
  return @"
  <form class="lead-form" data-lead-form>
    <div class="form-grid">
      <div class="field">
        <label for="name">שם</label>
        <input id="name" name="name" autocomplete="name" required>
      </div>
      <div class="field">
        <label for="phone">טלפון</label>
        <input id="phone" name="phone" inputmode="tel" autocomplete="tel" required>
      </div>
      <div class="field">
        <label for="pickup">עיר איסוף</label>
        <input id="pickup" name="pickup" autocomplete="address-level2">
      </div>
      <div class="field">
        <label for="destination">עיר יעד</label>
        <input id="destination" name="destination" autocomplete="address-level2">
      </div>
      <div class="$itemsClass">
        <label for="items">מה מובילים?</label>
        <textarea id="items" name="items" placeholder="לדוגמה: דירת 2 חדרים, מקרר, ספה, 20 ארגזים"></textarea>
      </div>
      <div class="field">
        <label for="date">תאריך רצוי</label>
        <input id="date" name="date" type="date">
      </div>
      <div class="field">
        <label for="elevator">האם יש מעלית?</label>
        <select id="elevator" name="elevator">
          <option value="">בחרו</option>
          <option>כן</option>
          <option>לא</option>
          <option>בצד אחד בלבד</option>
        </select>
      </div>
      <div class="field full">
        <label for="assembly">האם צריך פירוק והרכבה?</label>
        <select id="assembly" name="assembly">
          <option value="">בחרו</option>
          <option>כן</option>
          <option>לא</option>
          <option>עדיין לא בטוח</option>
        </select>
      </div>
    </div>
    <button class="btn btn-primary" type="submit">שלחו לי הצעת מחיר</button>
    <p class="form-note">הטופס פותח וואטסאפ ליצירת קשר מהירה.</p>
  </form>
"@
}

function HeroLeadFormHtml {
  return @"
          <form class="lead-form hero-lead-form" data-lead-form>
            <div class="field">
              <label for="hero-name">שם</label>
              <input id="hero-name" name="name" autocomplete="name" required>
            </div>
            <div class="field">
              <label for="hero-phone">טלפון</label>
              <input id="hero-phone" name="phone" inputmode="tel" autocomplete="tel" required>
            </div>
            <div class="field">
              <label for="hero-pickup">עיר איסוף</label>
              <input id="hero-pickup" name="pickup" autocomplete="address-level2">
            </div>
            <div class="field">
              <label for="hero-destination">עיר יעד</label>
              <input id="hero-destination" name="destination" autocomplete="address-level2">
            </div>
            <div class="field full">
              <label for="hero-items">מה מובילים?</label>
              <textarea id="hero-items" name="items"></textarea>
            </div>
            <button class="btn btn-primary" type="submit">שלחו בקשה להצעת מחיר</button>
          </form>
"@
}

function FaqHtml([array]$Faqs) {
  $html = ""
  foreach ($faq in $Faqs) {
    $html += @"
        <details>
          <summary>$(HtmlEncode $faq[0])</summary>
          <p>$(HtmlEncode $faq[1])</p>
        </details>
"@
  }
  return $html
}

function AreaTagsHtml([string]$Prefix) {
  $html = "<div class=""area-tags"">"
  foreach ($area in @($Config.serviceAreas.items)) {
    $html += "<span>$(HtmlEncode $area)</span>"
  }
  $html += "</div>"
  return $html
}

function ServiceCardsHtml([string]$Prefix) {
  $html = "      <div class=""grid grid-3"">`n"
  foreach ($service in $ConfiguredServices) {
    $html += @"
        <article class="service-card">
          <h3>$(HtmlEncode $service.name)</h3>
          <p>$(HtmlEncode $service.description)</p>
          <a href="$(Get-ServiceHref $service $Prefix)">קבלת פרטים</a>
        </article>
"@
  }
  $html += "      </div>"
  return $html
}

function Write-Page([string]$OutFile, [string]$Title, [string]$Description, [string]$Body, [array]$Schemas, [bool]$Landing = $false) {
  $prefix = Get-Prefix $OutFile
  $urlPath = Get-UrlPath $OutFile
  $canonical = $BaseUrl.TrimEnd("/") + $urlPath
  $schemaHtml = ""
  $allSchemas = New-Object System.Collections.Generic.List[object]
  if ($Schemas) { foreach ($schema in $Schemas) { $allSchemas.Add($schema) } }
  if ($urlPath -ne "/") { $allSchemas.Add((BreadcrumbSchema $Title $canonical)) }
  foreach ($schema in $allSchemas) { $schemaHtml += "`n  " + (JsonLd $schema) }
  $header = HeaderHtml $prefix $Landing
  $footer = FooterHtml $prefix $Landing
  $html = @"
<!doctype html>
<html lang="he" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$(HtmlEncode $Title)</title>
  <meta name="description" content="$(HtmlEncode $Description)">
  <link rel="canonical" href="$canonical">
  <meta property="og:locale" content="he_IL">
  <meta property="og:type" content="website">
  <meta property="og:title" content="$(HtmlEncode $Title)">
  <meta property="og:description" content="$(HtmlEncode $Description)">
  <meta property="og:url" content="$canonical">
  <meta property="og:image" content="$BaseUrl/assets/images/hero-moving-team.png">
  <link rel="preload" href="${prefix}assets/images/hero-moving-team.png" as="image">
  <link rel="stylesheet" href="${prefix}assets/css/styles.css">
  $schemaHtml
</head>
<body>
  <a class="skip-link" href="#main">דלגו לתוכן</a>
  $header
  <main id="main">
$Body
  </main>
  $footer
  <a class="floating-whatsapp btn btn-green" href="$WhatsappHref" data-whatsapp aria-label="שליחת וואטסאפ">וואטסאפ</a>
  <nav class="mobile-bottom" aria-label="פעולות מהירות במובייל">
    <a href="$PhoneHref" data-call>התקשר</a>
    <a href="$WhatsappHref" data-whatsapp>וואטסאפ</a>
    <a href="#quote">הצעת מחיר</a>
  </nav>
  <script src="${prefix}assets/js/main.js" defer></script>
</body>
</html>
"@
  Write-TextFile $OutFile $html
  $Pages.Add($canonical)
}

$HomeFaqs = @(
  @("איך מקבלים הצעת מחיר?", "שולחים כמה פרטים על הציוד, עיר איסוף, עיר יעד, קומה, מעלית ותאריך רצוי. אפשר לצרף תמונות בוואטסאפ כדי לדייק את ההצעה."),
  @("האם אפשר לקבל הצעת מחיר בוואטסאפ?", "כן. אפשר לשלוח פרטים ותמונות בוואטסאפ ולקבל הצעת מחיר מסודרת במהירות."),
  @("האם אתם עושים הובלות קטנות?", "כן. האתר מותאם גם להובלות קטנות, פריטים בודדים, סטודיו קטן ומחסן."),
  @("האם יש פירוק והרכבת רהיטים?", "אפשר לשלב פירוק והרכבה לפי סוג הרהיט והצורך בפועל."),
  @("האם אתם מובילים גם משרדים?", "כן. ניתן לתאם הובלות משרדים, עמדות עבודה, ציוד מחשוב וארגזים."),
  @("איך נקבע מחיר ההובלה?", "לפי כמות הציוד, מרחק, גישה לבניין, קומות, מעלית, צורך באריזה ופירוק והרכבה."),
  @("האם אפשר להזמין הובלה מהיום להיום?", "אם יש זמינות בלוח הזמנים, ננסה לתת מענה גם להובלות דחופות.")
)

$LocalBusinessSchema = [ordered]@{
  "@context" = "https://schema.org"
  "@type" = "MovingCompany"
  name = $BusinessName
  areaServed = $ServiceAreaText
  telephone = $PhoneSchema
  image = "$BaseUrl/assets/images/hero-moving-team.png"
  url = "$BaseUrl/"
}

$homeBody = @"
    <section class="hero">
      <div class="container hero-grid">
        <div class="hero-copy">
          <p class="eyebrow">$BusinessName - הובלות במרכז, בשפלה ובירושלים</p>
          <h1><span class="hero-title-full">הובלות במרכז, בשפלה ובירושלים — בלי כאב ראש</span><span class="hero-title-mobile">הובלות בלי כאב ראש</span></h1>
          <p>מעבר בטוח מבצעת הובלות קטנות וגדולות, דירות, משרדים, אריזה ופירוק והרכבה — עם תיאום ברור מראש, שמירה על הציוד והצעת מחיר מהירה בוואטסאפ.</p>
          <p class="hero-trust-line">תיאום ברור מראש, שמירה על הציוד ומענה מהיר בוואטסאפ.</p>
          <ul class="hero-points" aria-label="יתרונות השירות">
            <li>הובלות קטנות וגדולות</li>
            <li>הובלות דירה ומשרדים</li>
            <li>פירוק והרכבה לפי צורך</li>
            <li>שירות מאשקלון עד חיפה</li>
            <li>הצעת מחיר בוואטסאפ</li>
          </ul>
          <div class="cta-row">
            <a class="btn btn-green btn-xl" href="$WhatsappHref" data-whatsapp>קבלו הצעת מחיר בוואטסאפ</a>
            <a class="btn btn-light" href="$PhoneHref" data-call>התקשרו עכשיו</a>
          </div>
          <ul class="hero-mobile-trust" aria-label="נקודות אמון">
            <li>הצעה מהירה בוואטסאפ</li>
            <li>שמירה על הציוד</li>
            <li>שירות מאשקלון עד חיפה</li>
          </ul>
        </div>
        <div class="hero-form-panel lead-panel" aria-label="טופס הצעת מחיר מהירה">
          <h2>הצעת מחיר מהירה</h2>
          <p>השאירו פרטים ונחזור לתיאום לפי הציוד, הכתובות והזמינות.</p>
          $(HeroLeadFormHtml)
        </div>
      </div>
    </section>
    <section class="trust-strip" aria-label="פס אמון">
      <div class="container trust-grid">
        <div class="trust-item">תיאום ברור מראש</div>
        <div class="trust-item">בדיקת גישה וקומות</div>
        <div class="trust-item">עטיפה ושמירה על ציוד</div>
        <div class="trust-item">הצעה מסודרת בוואטסאפ</div>
        <div class="trust-item">שירות מאשקלון עד חיפה</div>
      </div>
    </section>
    <section class="section" id="services">
      <div class="container">
        <div class="section-heading">
          <div>
            <h2>שירותי הובלה שמתאימים למה שצריך באמת</h2>
            <p>מפריט אחד ועד מעבר דירה או משרד, עם תיאום ברור לפני ההובלה ומענה מהיר.</p>
          </div>
          <a class="btn btn-outline" href="contact/">דברו איתנו</a>
        </div>
        $(ServiceCardsHtml "")
      </div>
    </section>
    <section class="section lead-section" id="quote">
      <div class="container lead-wrap">
        <div class="lead-copy">
          <h2>קבלו הצעת מחיר מהירה וברורה</h2>
          <p>מלאו כמה פרטים בסיסיים, או שלחו תמונות בוואטסאפ. נחזור עם שאלה משלימה אם צריך ונבנה הצעה שמתאימה להובלה שלכם.</p>
          <ul class="lead-points">
            <li>בודקים את הפרטים לפני שמתחייבים למחיר.</li>
            <li>אפשר לשלוח תמונות כדי לדייק את המחיר.</li>
            <li>מתאים להובלות קטנות, דירות ומשרדים.</li>
          </ul>
        </div>
        <div class="lead-panel">
          $(LeadFormHtml $false)
        </div>
      </div>
    </section>
    <section class="section alt">
      <div class="container">
        <div class="section-heading">
          <div>
            <h2>איך זה עובד</h2>
            <p>תהליך קצר וברור, בלי סיבוכים מיותרים.</p>
          </div>
        </div>
        <div class="grid grid-4 steps">
          <div class="card step"><h3>שולחים פרטים</h3><p>פרטי ההובלה או תמונות בוואטסאפ.</p></div>
          <div class="card step"><h3>מקבלים הצעה</h3><p>הצעת מחיר ברורה לפי הציוד והגישה.</p></div>
          <div class="card step"><h3>קובעים שעה</h3><p>מתאמים מועד שמתאים לכם ולצוות.</p></div>
          <div class="card step"><h3>מובילים מסודר</h3><p>מגיעים, עוטפים, מעמיסים ומסיימים בצורה נקייה.</p></div>
        </div>
      </div>
    </section>
    <section class="section alt">
      <div class="container">
        <div class="section-heading">
          <div>
            <h2>אזורי שירות במרכז</h2>
            <p>מענה רחב באזור המרכז והסביבה, בהתאם לזמינות ולפרטי ההובלה.</p>
          </div>
        </div>
        $(AreaTagsHtml "")
      </div>
    </section>
    <section class="section">
      <div class="container">
        <div class="section-heading">
          <div>
            <h2>למה לבחור ב${BusinessName}?</h2>
            <p>הובלה טובה מתחילה בתיאום ברור ומסתיימת בציוד שמגיע כמו שצריך.</p>
          </div>
        </div>
        <ul class="why-list">
          <li>תיאום הגעה מסודר</li>
          <li>שמירה על הציוד בזמן העמסה</li>
          <li>הצעת מחיר ברורה מראש</li>
          <li>בדיקת קומות, מעלית וגישה</li>
          <li>מתאים להובלות קטנות וגדולות</li>
          <li>אפשר לשלוח תמונות להצעה מדויקת</li>
        </ul>
      </div>
    </section>
    <section class="section alt">
      <div class="container grid grid-2">
        <div>
          <div class="section-heading"><div><h2>סטנדרט עבודה ברור</h2><p>לפני שמגיעים, מוודאים את פרטי ההובלה כדי לצמצם הפתעות ביום המעבר.</p></div></div>
          <div class="testimonial-ready">בודקים עיר איסוף, עיר יעד, קומה, מעלית, גישה לבניין, כמות ציוד וצורך בפירוק או אריזה. כך הצוות מגיע מוכן יותר, והלקוח יודע למה לצפות.</div>
        </div>
        <div>
          <div class="section-heading"><div><h2>שאלות נפוצות</h2><p>תשובות קצרות לפני שמתקשרים.</p></div></div>
          <div class="faq">$(FaqHtml $HomeFaqs)</div>
        </div>
      </div>
    </section>
    <section class="section compact">
      <div class="container info-panel lead-panel">
        <div class="section-heading">
          <div>
            <h2>רוצים לבדוק מחיר להובלה הקרובה?</h2>
            <p>שלחו פרטים עכשיו ונחזור עם כיוון מסודר.</p>
          </div>
          <div class="cta-row">
            <a class="btn btn-green" href="$WhatsappHref" data-whatsapp>שליחת וואטסאפ</a>
            <a class="btn btn-primary" href="$PhoneHref" data-call>התקשר עכשיו</a>
          </div>
        </div>
      </div>
    </section>
"@

Write-Page "index.html" "הובלות במרכז, בשפלה ובירושלים בלי כאב ראש | $BusinessName" "מעבר בטוח מבצעת הובלות קטנות וגדולות, דירות, משרדים, אריזה ופירוק והרכבה — עם תיאום ברור מראש, שמירה על הציוד והצעת מחיר מהירה בוואטסאפ." $homeBody @($LocalBusinessSchema, (FaqSchema $HomeFaqs))

$services = @(
  [ordered]@{ Slug = "hovalot-ktanot"; Title = "הובלות קטנות במרכז"; Meta = "הובלות קטנות במרכז לפריטים בודדים, דירות קטנות ומעברים נקודתיים. קבלו הצעת מחיר מהירה בוואטסאפ."; Intro = "כשלא צריך משאית ענקית אלא צוות זריז ומדויק, הובלה קטנה יכולה לחסוך זמן וכסף. אנחנו מתאמים את ההובלה לפי כמות הציוד, הגישה לבניין והמרחק."; Points = @("פריטים בודדים, מחסנים וסטודיו קטן", "תיאום מהיר לפי זמינות", "שמירה על פריטים רגישים ועטיפה לפי צורך") },
  [ordered]@{ Slug = "hovalat-dira"; Title = "הובלת דירה במרכז"; Meta = "הובלת דירה במרכז עם שירות מקצועי, מסודר ומהיר. מעבר דירה עם הצעת מחיר ברורה ושמירה על הציוד."; Intro = "מעבר דירה דורש סדר: להבין מה מובילים, לבדוק קומות ומעלית, לתכנן זמן הגעה ולשמור על הציוד לאורך כל הדרך."; Points = @("הובלות דירות קטנות וגדולות", "אפשרות לפירוק והרכבה", "תכנון לפי כמות ציוד, קומות ומרחק") },
  [ordered]@{ Slug = "hovalot-misradim"; Title = "הובלות משרדים במרכז"; Meta = "הובלות משרדים במרכז לעסקים קטנים ובינוניים, עמדות עבודה, ציוד מחשוב וארגזים."; Intro = "בהובלת משרד חשוב לצמצם זמן השבתה ולשמור על ציוד העבודה. לכן מתאמים מראש מה עובר, באיזה סדר, ומה חייב להגיע ראשון."; Points = @("עמדות עבודה, ארגזים וציוד מחשוב", "תיאום שעות נוח לעסק", "עבודה מסודרת מול איש קשר אחד") },
  [ordered]@{ Slug = "hovalat-pritim"; Title = "הובלת פריטים בודדים"; Meta = "הובלת פריטים בודדים במרכז: מקרר, ספה, מכונת כביסה, ארון, מיטה ופריטים כבדים."; Intro = "צריך להעביר רק פריט אחד או כמה פריטים? אפשר לקבל הצעה לפי סוג הפריט, מידות, קומה, מעלית ויעד."; Points = @("מקרר, ספה, מכונת כביסה וארונות", "פתרון נוח לקנייה מיד שנייה", "בדיקת גישה כדי למנוע הפתעות") },
  [ordered]@{ Slug = "piruk-harkava"; Title = "פירוק והרכבת רהיטים"; Meta = "פירוק והרכבת רהיטים כחלק מהובלה במרכז. שירות נוח לארונות, מיטות ורהיטים גדולים."; Intro = "יש רהיטים שלא עוברים בדלת או במעלית בלי פירוק. אפשר לשלב פירוק והרכבה כחלק מההובלה לפי סוג הרהיט והמצב בשטח."; Points = @("פירוק מיטות, ארונות ורהיטים גדולים", "הרכבה במקום החדש לפי הצורך", "תיאום מראש כדי להעריך זמן ועלות") }
)

foreach ($service in $services) {
  $faqs = @(
    @("איך מקבלים מחיר ל$($service.Title)?", "שולחים פרטים בסיסיים: מה מובילים, עיר איסוף, עיר יעד, קומה, מעלית ותאריך רצוי. אפשר לצרף תמונות בוואטסאפ."),
    @("האם המחיר סופי מראש?", "אחרי קבלת הפרטים ניתן לתת הצעה ברורה יותר. המחיר הסופי תלוי בפרטים בפועל ובשינויים ביום ההובלה."),
    @("אפשר להזמין שירות דחוף?", "אם יש זמינות, ננסה לתת מענה גם להובלות קרובות או מהיום להיום.")
  )
  $pointsHtml = ($service.Points | ForEach-Object { "<li>$(HtmlEncode $_)</li>" }) -join ""
  $body = @"
    <section class="page-hero">
      <div class="container">
        <div class="breadcrumbs"><a href="../">דף הבית</a> / שירותים</div>
        <h1>$($service.Title)</h1>
        <p>$($service.Intro)</p>
        <div class="cta-row">
          <a class="btn btn-primary" href="#quote">קבל הצעת מחיר</a>
          <a class="btn btn-green" href="$WhatsappHref" data-whatsapp>וואטסאפ מהיר</a>
          <a class="btn btn-light" href="$PhoneHref" data-call>התקשר עכשיו</a>
        </div>
      </div>
    </section>
    <section class="section">
      <div class="container split">
        <article class="content">
          <h2>מה כולל השירות?</h2>
          <p>$($service.Intro)</p>
          <ul>$pointsHtml</ul>
          <h2>איך מתאמים הובלה בלי הפתעות?</h2>
          <p>לפני ההובלה חשוב לציין כמה שיותר פרטים: מספר פריטים, קומה, מעלית, מרחק הליכה מהחניה, פירוק והרכבה אם צריך, ותאריך רצוי. ככל שהמידע מדויק יותר, כך הצעת המחיר תהיה ברורה יותר.</p>
          <div class="cta-row">
            <a class="btn btn-green" href="$WhatsappHref" data-whatsapp>שלחו פרטים בוואטסאפ</a>
            <a class="btn btn-outline" href="#quote">קבלו הצעת מחיר</a>
          </div>
          <h2>שאלות נפוצות</h2>
          <div class="faq">$(FaqHtml $faqs)</div>
        </article>
        <aside class="lead-panel sidebar-cta" id="quote">
          <h2>הצעת מחיר ל$($service.Title)</h2>
          <p>מלאו פרטים ונפתח הודעת וואטסאפ מוכנה.</p>
          $(LeadFormHtml $true)
        </aside>
      </div>
    </section>
    <section class="section alt compact">
      <div class="container info-panel lead-panel">
        <div class="section-heading">
          <div><h2>רוצים לבדוק זמינות?</h2><p>אפשר להתקשר או לשלוח וואטסאפ עם תמונות של הציוד.</p></div>
          <div class="cta-row"><a class="btn btn-green" href="$WhatsappHref" data-whatsapp>וואטסאפ</a><a class="btn btn-primary" href="$PhoneHref" data-call>התקשר</a></div>
        </div>
      </div>
    </section>
"@
  $schema = [ordered]@{ "@context" = "https://schema.org"; "@type" = "Service"; serviceType = $service.Title; provider = [ordered]@{ "@type" = "MovingCompany"; name = $BusinessName }; areaServed = "אזור המרכז" }
  Write-Page "$($service.Slug)/index.html" "$($service.Title) | $BusinessName" $service.Meta $body @($schema, (FaqSchema $faqs))
}

$priceCheckFaqs = @(
  @("למה אי אפשר לתת מחיר מדויק בלי פרטים?", "מחיר הובלה תלוי בפרטי העבודה בפועל: כמות הציוד, קומות, מעלית, מרחק הליכה, מרחק נסיעה, צורך בפירוק והרכבה ושירותי אריזה."),
  @("איזה פרטים כדאי לשלוח בוואטסאפ?", "כדאי לשלוח עיר איסוף, עיר יעד, קומה, האם יש מעלית, מה מובילים, האם צריך פירוק והרכבה ותאריך רצוי."),
  @("האם תמונות עוזרות לקבל הצעת מחיר?", "כן. תמונות של הרהיטים, הארגזים והגישה לבניין עוזרות להבין את היקף העבודה ולהחזיר הצעה מסודרת יותר.")
)

$priceCheckBody = @"
    <section class="page-hero">
      <div class="container">
        <div class="breadcrumbs"><a href="../">דף הבית</a> / בדיקת מחיר</div>
        <h1>בדיקת מחיר להובלה</h1>
        <p>כדי לתת הצעה מסודרת צריך להבין את פרטי ההובלה, הגישה, כמות הציוד והשירותים הנלווים.</p>
        <div class="cta-row">
          <a class="btn btn-green" href="$WhatsappHref" data-whatsapp>בדיקת מחיר בוואטסאפ</a>
          <a class="btn btn-light" href="$PhoneHref" data-call>התקשרו עכשיו</a>
        </div>
      </div>
    </section>
    <section class="section">
      <div class="container split">
        <article class="content">
          <h2>איך נקבע מחיר הובלה?</h2>
          <p>מחיר הובלה נקבע לפי העבודה בפועל: כמות הציוד, סוג הפריטים, קומות, מעלית, מרחק הליכה מהחניה, מרחק הנסיעה, צורך בפירוק והרכבה, שירותי אריזה וזמינות ביום המבוקש.</p>

          <h2>למה אי אפשר לתת מחיר מדויק בלי פרטים?</h2>
          <p>שתי הובלות שנראות דומות יכולות להיות שונות מאוד בשטח. דירה עם מעלית וגישה נוחה אינה דומה לדירה בלי מעלית, עם הליכה ארוכה או פריטים שדורשים פירוק. לכן ב$BusinessName בודקים קודם את הפרטים ורק אז חוזרים עם הצעת מחיר מסודרת.</p>

          <h2>איזה פרטים צריך לשלוח?</h2>
          <ul>
            <li>עיר איסוף ועיר יעד.</li>
            <li>קומה בכל צד והאם יש מעלית.</li>
            <li>מה מובילים: רהיטים, מוצרי חשמל, ארגזים ופריטים רגישים.</li>
            <li>האם צריך פירוק והרכבת רהיטים.</li>
            <li>תאריך רצוי וגמישות בשעה.</li>
            <li>פרטים על גישה, חניה או מרחק הליכה מהבניין.</li>
          </ul>

          <h2>איך לשלוח תמונות בוואטסאפ?</h2>
          <p>אפשר לשלוח תמונות של הרהיטים, הארגזים, מוצרי החשמל והגישה לבניין. תמונות ברורות עוזרות להבין את נפח העבודה, לזהות פריטים שדורשים עטיפה או פירוק, ולצמצם אי הבנות לפני יום ההובלה.</p>

          <h2>מה משפיע על המחיר?</h2>
          <p>הגורמים המרכזיים הם נפח הציוד, משקל הפריטים, קומות, מעלית, מרחק מהחניה, מרחק הנסיעה, זמינות, שירותי אריזה ופירוק והרכבה. ככל שהפרטים מדויקים יותר, כך ההצעה תהיה ברורה יותר.</p>

          <h2>איך להימנע מהפתעות ביום ההובלה?</h2>
          <p>כדאי לשלוח מראש את כל הפרטים הרלוונטיים, לעדכן על פריטים כבדים או שבירים, לציין אם אין מעלית, ולצלם את הגישה לבניין אם היא מורכבת. כך אפשר לתאם נכון את הצוות, הזמן והציוד הנדרש.</p>

          <div class="info-panel lead-panel">
            <div class="section-heading">
              <div>
                <h2>שלחו פרטים בוואטסאפ וקבלו הצעת מחיר</h2>
                <p>שלחו את פרטי ההובלה ותמונות אם יש, ונחזור עם הצעה מסודרת לפי העבודה בפועל.</p>
              </div>
              <div class="cta-row">
                <a class="btn btn-green" href="$WhatsappHref" data-whatsapp>בדיקת מחיר בוואטסאפ</a>
              </div>
            </div>
          </div>
        </article>
        <aside class="lead-panel sidebar-cta" id="quote">
          <h2>בדיקת מחיר מהירה</h2>
          <p>מלאו פרטים ונפתח הודעת וואטסאפ ליצירת קשר.</p>
          $(LeadFormHtml $true)
        </aside>
      </div>
    </section>
    <section class="section alt">
      <div class="container">
        <div class="section-heading"><div><h2>שאלות נפוצות על בדיקת מחיר</h2></div></div>
        <div class="faq">$(FaqHtml $priceCheckFaqs)</div>
      </div>
    </section>
"@

Write-Page "mehiron-hovalot/index.html" "בדיקת מחיר להובלה | $BusinessName" "צריכים לדעת כמה תעלה ההובלה? במעבר בטוח בודקים את פרטי ההובלה, כמות הציוד, קומות, מעלית, מרחק ושירותים נלווים — וחוזרים עם הצעת מחיר מסודרת בוואטסאפ." $priceCheckBody @((FaqSchema $priceCheckFaqs))

$areasBody = @"
    <section class="page-hero">
      <div class="container">
        <div class="breadcrumbs"><a href="../">דף הבית</a> / אזורי שירות</div>
        <h1>אזורי שירות להובלות במרכז</h1>
        <p>שירותי הובלה במרכז הארץ, עם דפי עיר שמרכזים מידע מקומי, קישורים מהירים וטופס הצעת מחיר.</p>
        <div class="cta-row"><a class="btn btn-green" href="$WhatsappHref" data-whatsapp>בדיקת זמינות בוואטסאפ</a><a class="btn btn-primary" href="../contact/">השארת פרטים</a></div>
      </div>
    </section>
    <section class="section"><div class="container"><div class="section-heading"><div><h2>בחרו עיר</h2><p>אפשר לקבל הצעה גם לערים סמוכות בהתאם לזמינות.</p></div></div>$(AreaTagsHtml "../")</div></section>
    <section class="section lead-section" id="quote"><div class="container lead-wrap"><div class="lead-copy"><h2>לא בטוחים אם אנחנו מגיעים אליכם?</h2><p>שלחו עיר איסוף ויעד ונבדוק זמינות.</p></div><div class="lead-panel">$(LeadFormHtml $true)</div></div></section>
"@
Write-Page "azorei-sherut/index.html" "אזורי שירות להובלות במרכז | $BusinessName" "רשימת אזורי שירות להובלות במרכז: תל אביב, רמת גן, גבעתיים, חולון, בת ים, פתח תקווה, הרצליה ועוד." $areasBody @($LocalBusinessSchema)

$cities = @(
  [ordered]@{ Name = "תל אביב"; Slug = "hovalot-tel-aviv"; Angle = "בתל אביב חשוב לתאם הובלה לפי חניה, מעלית, רחובות צרים ושעות עומס. לכן אנחנו מבקשים מראש כמה פרטים על הגישה לבניין."; Areas = "מרכז העיר, הצפון הישן, יד אליהו, פלורנטין, רמת אביב והסביבה" },
  [ordered]@{ Name = "רמת גן"; Slug = "hovalot-ramat-gan"; Angle = "ברמת גן יש שילוב של בניינים ותיקים, מגדלים ורחובות צפופים, ולכן תכנון הגישה והחניה משפיע מאוד על ההובלה."; Areas = "מרום נווה, הבורסה, מרכז העיר, רמת חן ונווה יהושע" },
  [ordered]@{ Name = "גבעתיים"; Slug = "hovalot-givatayim"; Angle = "בגבעתיים הובלה טובה מתחילה בבדיקה של רחוב, קומה ומעלית, במיוחד בבניינים ותיקים ובאזורים צפופים."; Areas = "בורוכוב, שינקין, ארלוזורוב, כורזין והסביבה" },
  [ordered]@{ Name = "חולון"; Slug = "hovalot-holon"; Angle = "בחולון ניתן לתאם הובלות קטנות וגדולות, מדירות בבניינים ותיקים ועד מעברים בשכונות החדשות."; Areas = "קריית שרת, נאות רחל, ח-300, תל גיבורים ומרכז חולון" },
  [ordered]@{ Name = "בת ים"; Slug = "hovalot-bat-yam"; Angle = "בבת ים חשוב לתכנן מראש את הגישה לבניין ואת המרחק מהחניה, במיוחד ברחובות עמוסים ובקרבת הטיילת."; Areas = "רמת הנשיא, מרכז העיר, עמידר, הטיילת והסביבה" },
  [ordered]@{ Name = "ראשון לציון"; Slug = "hovalot-rishon-lezion"; Angle = "בראשון לציון מתאמים הובלות בין שכונות ותיקות וחדשות, עם התאמה לכמות הציוד ולמרחק הנסיעה."; Areas = "מערב העיר, מרכז העיר, רמת אליהו, נווה דקלים ונחלת יהודה" },
  [ordered]@{ Name = "פתח תקווה"; Slug = "hovalot-petah-tikva"; Angle = "בפתח תקווה יש ביקוש גבוה להובלות דירה, פריטים בודדים ומשרדים, ולכן כדאי לתאם מועד מוקדם ככל האפשר."; Areas = "אם המושבות, כפר גנים, מרכז העיר, הדר גנים וקריית מטלון" },
  [ordered]@{ Name = "בני ברק"; Slug = "hovalot-bnei-brak"; Angle = "בבני ברק חשוב לתאם שעות, גישה וחניה בצורה מסודרת, במיוחד ברחובות צפופים ובבניינים עם עומס תנועה."; Areas = "פרדס כץ, קריית הרצוג, מרכז העיר ורמת אהרן" },
  [ordered]@{ Name = "הרצליה"; Slug = "hovalot-herzliya"; Angle = "בהרצליה אפשר לתאם הובלות דירה, פריטים ומשרדים, עם בדיקה מוקדמת של גישה, חניה ומעלית."; Areas = "הרצליה פיתוח, מרכז העיר, נווה עמל, גליל ים והסביבה" },
  [ordered]@{ Name = "רעננה"; Slug = "hovalot-raanana"; Angle = "ברעננה נפוצות הובלות מדירות ובתים פרטיים, ולכן חשוב להבין מראש את המרחק מהחניה ואת נפח הציוד."; Areas = "מרכז העיר, קריית שרת, לב הפארק, נווה זמר והסביבה" },
  [ordered]@{ Name = "קריית אונו"; Slug = "hovalot-kiryat-ono"; Angle = "בקריית אונו אפשר לתאם הובלות קטנות וגדולות, כולל פריטים בודדים ומעברי דירה באזור בקעת אונו."; Areas = "פסגת אונו, רייספלד, מרכז קריית אונו והסביבה" },
  [ordered]@{ Name = "אור יהודה"; Slug = "hovalot-or-yehuda"; Angle = "באור יהודה ניתן לתאם הובלות לפי זמינות, עם מענה להובלות קטנות, דירות ופריטים בודדים."; Areas = "נווה רבין, סקיה, מרכז העיר והסביבה" },
  [ordered]@{ Name = "יהוד"; Slug = "hovalot-yehud"; Angle = "ביהוד והסביבה מתאמים הובלות דירה, פריטים ושירותי פירוק והרכבה לפי הצורך בשטח."; Areas = "יהוד, מונוסון, אזור התעשייה והסביבה" }
)

foreach ($city in $cities) {
  $faqs = @(
    @("האם אפשר להזמין הובלה ב$($city.Name)?", "כן, בהתאם לזמינות ולפרטי ההובלה. כדאי לשלוח עיר איסוף, עיר יעד ותיאור ציוד."),
    @("מה משפיע על מחיר הובלה ב$($city.Name)?", "קומה, מעלית, מרחק מהחניה, כמות ציוד, פירוק והרכבה ומרחק הנסיעה."),
    @("אפשר לשלוח תמונות בוואטסאפ?", "כן. תמונות עוזרות להבין נפח, פריטים רגישים וגישה.")
  )
  $body = @"
    <section class="page-hero">
      <div class="container">
        <div class="breadcrumbs"><a href="../">דף הבית</a> / <a href="../azorei-sherut/">אזורי שירות</a></div>
        <h1>הובלות ב$($city.Name)</h1>
        <p>$($city.Angle)</p>
        <div class="cta-row"><a class="btn btn-primary" href="#quote">קבל הצעת מחיר</a><a class="btn btn-green" href="$WhatsappHref" data-whatsapp>וואטסאפ</a><a class="btn btn-light" href="$PhoneHref" data-call>התקשר</a></div>
      </div>
    </section>
    <section class="section">
      <div class="container split">
        <article class="content">
          <h2>שירותי הובלה ב$($city.Name)</h2>
          <p>ב$($city.Name) ניתן לתאם הובלות קטנות, הובלות דירה, הובלות משרדים, הובלת פריטים בודדים ופירוק והרכבת רהיטים. לפני קביעת המחיר נבדוק את פרטי הגישה ואת כמות הציוד.</p>
          <h2>אזורים ושכונות רלוונטיים</h2>
          <p>$($city.Areas). נותנים מענה גם לערים סמוכות בהתאם לזמינות.</p>
          <h2>איך מקבלים הצעה מהירה?</h2>
          <p>שלחו בוואטסאפ כמה פרטים: עיר איסוף, עיר יעד, מה מובילים, קומה, מעלית ותאריך רצוי. אם אפשר, צרפו תמונות של הפריטים או הארגזים.</p>
          <div class="cta-row"><a class="btn btn-green" href="$WhatsappHref" data-whatsapp>שליחת פרטים בוואטסאפ</a><a class="btn btn-outline" href="../hovalot-ktanot/">הובלות קטנות</a><a class="btn btn-outline" href="../hovalat-dira/">הובלת דירה</a></div>
          <h2>שאלות נפוצות על הובלות ב$($city.Name)</h2>
          <div class="faq">$(FaqHtml $faqs)</div>
        </article>
        <aside class="lead-panel sidebar-cta" id="quote">
          <h2>הצעת מחיר להובלה ב$($city.Name)</h2>
          $(LeadFormHtml $true)
        </aside>
      </div>
    </section>
"@
  $schema = [ordered]@{ "@context" = "https://schema.org"; "@type" = "Service"; serviceType = "הובלות ב$($city.Name)"; provider = [ordered]@{ "@type" = "MovingCompany"; name = $BusinessName }; areaServed = $city.Name }
  Write-Page "$($city.Slug)/index.html" "הובלות ב$($city.Name) | $BusinessName" "הובלות ב$($city.Name): דירות, הובלות קטנות, פריטים בודדים ומשרדים. קבלו הצעת מחיר מהירה בוואטסאפ." $body @($schema, (FaqSchema $faqs))
}

$contactBody = @"
    <section class="page-hero">
      <div class="container">
        <div class="breadcrumbs"><a href="../">דף הבית</a> / צור קשר</div>
        <h1>צור קשר וקבלת הצעת מחיר</h1>
        <p>ספרו לנו מה מובילים, מאיפה ולאן, ונחזור עם כיוון מחיר וזמינות.</p>
        <div class="cta-row"><a class="btn btn-green" href="$WhatsappHref" data-whatsapp>וואטסאפ</a><a class="btn btn-light" href="$PhoneHref" data-call>התקשר עכשיו</a></div>
      </div>
    </section>
    <section class="section lead-section" id="quote"><div class="container lead-wrap"><div class="lead-copy"><h2>השאירו פרטים</h2><p>אפשר גם להתקשר ישירות ל-<span data-phone-text>$PhoneDisplay</span>.</p><ul class="lead-points"><li>הצעה לפי פרטי ההובלה בפועל.</li><li>מענה להובלות קטנות וגדולות.</li><li>אפשר לשלוח תמונות בוואטסאפ.</li></ul></div><div class="lead-panel">$(LeadFormHtml $false)</div></div></section>
"@
Write-Page "contact/index.html" "צור קשר | קבלת הצעת מחיר להובלה | $BusinessName" "השאירו פרטים וקבלו הצעת מחיר להובלה במרכז. אפשר לשלוח וואטסאפ או להתקשר." $contactBody @($LocalBusinessSchema)

$privacyBody = @"
    <section class="page-hero"><div class="container"><div class="breadcrumbs"><a href="../">דף הבית</a> / מדיניות פרטיות</div><h1>מדיניות פרטיות</h1><p>מסמך בסיסי לאתר תדמיתי לקבלת פניות מלקוחות.</p></div></section>
    <section class="section"><div class="container content"><h2>איזה מידע נאסף?</h2><p>בעת מילוי טופס באתר ייתכן שייאספו שם, טלפון, עיר איסוף, עיר יעד ותיאור ההובלה, כדי שנוכל לחזור אליכם עם הצעת מחיר.</p><h2>שימוש במידע</h2><p>המידע משמש ליצירת קשר, תיאום שירות ומתן הצעת מחיר. אין להשתמש במידע מעבר למטרות אלה ללא צורך עסקי או דרישה חוקית.</p><h2>עדכון פרטים</h2><p>ניתן לפנות אלינו כדי לבקש עדכון או מחיקה של פרטים שנמסרו דרך האתר.</p></div></section>
"@
Write-Page "privacy/index.html" "מדיניות פרטיות | $BusinessName" "מדיניות פרטיות בסיסית לאתר מעבר בטוח וקבלת פניות להובלות." $privacyBody @()

$articles = @(
  [ordered]@{ Slug = "kama-ole-hovala-bamerkaz"; Title = "כמה עולה הובלה במרכז?"; Intro = "מחיר הובלה במרכז משתנה לפי נפח הציוד, קומות, מעלית, מרחק, פירוק והרכבה ותאריך רצוי."; Bullets = @("הכינו רשימת ציוד קצרה", "ציינו קומה ומעלית בשני הצדדים", "שלחו תמונות כדי לקבל הערכה מדויקת יותר") },
  [ordered]@{ Slug = "eich-livhor-movil-amin"; Title = "איך לבחור מוביל אמין?"; Intro = "מוביל אמין נותן הצעה ברורה, שואל שאלות נכונות, מסביר מה כלול ושומר על תקשורת זמינה."; Bullets = @("בדקו זמינות ושעת הגעה", "וודאו מה כלול במחיר", "העדיפו הצעה כתובה בוואטסאפ") },
  [ordered]@{ Slug = "ma-mashpia-al-mehir-hovala"; Title = "מה משפיע על מחיר הובלה?"; Intro = "המחיר נקבע בעיקר לפי עבודה בפועל: כמות ציוד, גישה, מרחק, קומות ושירותים נוספים."; Bullets = @("מרחק מהחניה לדירה", "צורך בפירוק והרכבה", "שירותי אריזה ועטיפה") },
  [ordered]@{ Slug = "hovalot-ktanot-matai-mishtalem"; Title = "הובלות קטנות - מתי זה משתלם?"; Intro = "הובלה קטנה מתאימה כשיש מעט ציוד, פריט בודד או מעבר קצר שלא מצדיק הובלה גדולה."; Bullets = @("מעבר סטודיו או חדר", "קנייה מיד שנייה", "העברת פריט כבד אחד") },
  [ordered]@{ Slug = "hachana-lemaavar-dira"; Title = "איך להתכונן למעבר דירה?"; Intro = "הכנה טובה חוסכת זמן ביום המעבר: אריזה מסודרת, סימון ארגזים ותיאום גישה."; Bullets = @("סמנו ארגזים לפי חדר", "הפרידו ציוד שביר", "דאגו לחניה וגישה") },
  [ordered]@{ Slug = "reshimat-tziud-lemaavar"; Title = "רשימת ציוד למעבר דירה"; Intro = "רשימת ציוד מסודרת עוזרת לקבל הצעת מחיר טובה יותר ולמנוע הפתעות."; Bullets = @("רהיטים גדולים", "מוצרי חשמל", "מספר ארגזים משוער") },
  [ordered]@{ Slug = "sherutei-ariza-kedai"; Title = "האם כדאי להזמין שירותי אריזה?"; Intro = "שירותי אריזה יכולים להתאים כשאין זמן, כשיש ציוד רגיש או כשצריך מעבר מסודר במיוחד."; Bullets = @("ציוד שביר", "מטבח מלא", "חיסכון בזמן לפני המעבר") },
  [ordered]@{ Slug = "hovalat-mekarer-mechonat-kvisa"; Title = "איך מובילים מקרר או מכונת כביסה?"; Intro = "מוצרי חשמל כבדים דורשים הובלה יציבה, קשירה נכונה והקפדה על גישה בטוחה."; Bullets = @("רוקנו ונתקו מראש", "מדדו מעברים ודלתות", "עדכנו אם אין מעלית") },
  [ordered]@{ Slug = "dira-bli-maalit"; Title = "הובלת דירה בלי מעלית - מה חשוב לדעת?"; Intro = "כשאין מעלית, מספר הקומות והגישה משפיעים על זמן העבודה ועל המחיר."; Bullets = @("ציינו קומות בשני הצדדים", "בדקו רוחב חדר מדרגות", "עדכנו על פריטים כבדים במיוחד") },
  [ordered]@{ Slug = "hovalot-mehayom-lehayom"; Title = "הובלות מהיום להיום - מתי זה אפשרי?"; Intro = "הובלה מהיום להיום אפשרית רק כשיש צוות פנוי וכאשר פרטי ההובלה ברורים מספיק לתיאום מהיר."; Bullets = @("שלחו פרטים מלאים מיד", "היו גמישים בשעה", "ציינו אם צריך פירוק והרכבה") }
)

$articleCards = ""
foreach ($article in $articles) {
  $articleCards += "<article class=""article-card""><h3>$($article.Title)</h3><p>$($article.Intro)</p><a href=""$($article.Slug)/"">קראו מדריך</a></article>"
}
$blogBody = @"
    <section class="page-hero"><div class="container"><div class="breadcrumbs"><a href="../">דף הבית</a> / מדריכים</div><h1>בלוג ומדריכי הובלות</h1><p>תשתית תוכן ל-SEO: שאלות נפוצות, הכנות למעבר וטיפים לקבלת הצעת מחיר מדויקת.</p></div></section>
    <section class="section"><div class="container"><div class="grid grid-3">$articleCards</div></div></section>
    <section class="section lead-section" id="quote"><div class="container lead-wrap"><div class="lead-copy"><h2>מתלבטים לגבי הובלה?</h2><p>אפשר לקרוא מדריכים, אבל הדרך הכי מהירה להבין מחיר היא לשלוח פרטים ותמונות.</p><ul class="lead-points"><li>הצעת מחיר לפי הפרטים בפועל</li><li>מענה להובלות קטנות וגדולות</li><li>אפשר לשלוח תמונות בוואטסאפ</li></ul></div><div class="lead-panel">$(LeadFormHtml $true)</div></div></section>
"@
Write-Page "blog/index.html" "בלוג הובלות ומדריכים | $BusinessName" "מדריכי הובלות במרכז: מחיר, בחירת מוביל, הכנה למעבר, הובלות קטנות ושירותי אריזה." $blogBody @()

foreach ($article in $articles) {
  $bullets = ($article.Bullets | ForEach-Object { "<li>$(HtmlEncode $_)</li>" }) -join ""
  $body = @"
    <section class="page-hero"><div class="container"><div class="breadcrumbs"><a href="../../">דף הבית</a> / <a href="../">מדריכים</a></div><h1>$($article.Title)</h1><p>$($article.Intro)</p><div class="cta-row"><a class="btn btn-green" href="$WhatsappHref" data-whatsapp>שאלו בוואטסאפ</a><a class="btn btn-light" href="$PhoneHref" data-call>התקשרו</a></div></div></section>
    <section class="section"><div class="container split"><article class="content"><h2>עיקרי הדברים</h2><p>$($article.Intro)</p><ul>$bullets</ul><h2>איך ממשיכים מכאן?</h2><p>כדי לקבל הצעת מחיר שמתאימה להובלה שלכם, שלחו פרטי איסוף ויעד, תאריך רצוי, רשימת ציוד ותמונות אם יש. כך אפשר לצמצם הפתעות ולתאם את העבודה בצורה מסודרת.</p></article><aside class="lead-panel sidebar-cta" id="quote"><h2>בדיקת מחיר מהירה</h2>$(LeadFormHtml $true)</aside></div></section>
"@
  Write-Page "blog/$($article.Slug)/index.html" "$($article.Title) | מדריך הובלות | $BusinessName" "$($article.Intro) מדריך קצר לקבלת החלטה נכונה לפני הובלה." $body @()
}

$landingFaqs = @(
  @("כמה מהר אפשר לקבל הצעת מחיר?", "ברוב המקרים אפשר לקבל כיוון ראשוני אחרי שליחת פרטים ותמונות בוואטסאפ."),
  @("האם המחיר סופי?", "המחיר הסופי תלוי בפרטי ההובלה בפועל. ננסה לדייק מראש כדי למנוע הפתעות."),
  @("האם יש הובלות קטנות?", "כן, אפשר לתאם גם פריט בודד או כמה פריטים.")
)
$landingBody = @"
    <section class="hero landing-hero">
      <div class="container">
        <div class="hero-copy">
          <p class="eyebrow">$BusinessName - קמפיין הובלות במרכז</p>
          <h1>צריכים הובלה במרכז? קבלו הצעת מחיר מהירה וברורה</h1>
          <p>הובלות קטנות וגדולות, דירות, משרדים ופריטים בודדים. שלחו פרטים בוואטסאפ או השאירו טלפון ונחזור אליכם.</p>
          <div class="cta-row"><a class="btn btn-green" href="$WhatsappHref" data-whatsapp>וואטסאפ להצעת מחיר</a><a class="btn btn-light" href="$PhoneHref" data-call>התקשר עכשיו</a></div>
        </div>
      </div>
    </section>
    <section class="section lead-section" id="quote"><div class="container lead-wrap"><div class="lead-copy"><h2>טופס מהיר להצעת מחיר</h2><p>מלאו את הפרטים החשובים בלבד. ההודעה תיפתח בוואטסאפ ותוכלו לצרף תמונות.</p><ul class="lead-points"><li>מחיר הוגן לפי פרטי ההובלה</li><li>שירות אישי וזמינות גבוהה</li><li>שמירה על הציוד</li></ul></div><div class="lead-panel">$(LeadFormHtml $true)</div></div></section>
    <section class="section"><div class="container"><div class="section-heading"><div><h2>אזורי שירות</h2><p>$ServiceAreaText</p></div></div>$(AreaTagsHtml "../../")</div></section>
    <section class="section"><div class="container grid grid-2"><div><h2>למה להשאיר פרטים?</h2><ul class="why-list"><li>הצעה לפי הציוד שלכם</li><li>אפשר לשלוח תמונות</li><li>מענה מהיר לתיאום</li></ul></div><div><h2>שאלות קצרות</h2><div class="faq">$(FaqHtml $landingFaqs)</div></div></div></section>
"@
Write-Page "lp/hovalot-bamerkaz/index.html" "הובלות במרכז | הצעת מחיר מהירה | $BusinessName" "דף נחיתה לקמפיין הובלות במרכז: טופס מהיר, וואטסאפ, שירותי הובלה ואזורי שירות." $landingBody @((FaqSchema $landingFaqs)) $true

$sitemapUrls = ($Pages | ForEach-Object { "  <url><loc>$_</loc></url>" }) -join "`n"
Write-TextFile "sitemap.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$sitemapUrls
</urlset>
"@

Write-TextFile "robots.txt" @"
User-agent: *
Allow: /

Sitemap: $BaseUrl/sitemap.xml
"@

Write-Host "Generated $($Pages.Count) pages."
