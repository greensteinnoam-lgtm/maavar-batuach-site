# מעבר בטוח - אתר הובלות

אתר סטטי בעברית לחברת הובלות באזור המרכז, כולל דף בית, דפי שירות, דפי עיר ל-SEO, מחירון, צור קשר, בלוג ודף נחיתה לקמפיין Google Ads.

## עריכה מהירה

- שם עסק, טלפון, וואטסאפ ומייל: `assets/js/main.js`
- צבעים ועיצוב: `assets/css/styles.css`
- תוכן עמודים, אזורי שירות, מחירון ומאמרים: `tools/build-site.ps1`
- תמונת Hero: `assets/images/hero-moving-team.png`

אחרי שינוי תוכן במחולל:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-site.ps1
```

## פרסום

האתר בנוי כקבצים סטטיים ולכן מתאים ל-GitHub Pages, Netlify, Cloudflare Pages או כל אחסון סטטי אחר. לפני פרסום אמיתי כדאי להחליף את `https://example.com` בדומיין הסופי בתוך `tools/build-site.ps1`, ואז להריץ את המחולל שוב.

## GitHub

המאגר המקומי יכול להתחבר ל-GitHub עם remote בשם `origin`. אם אין כלי GitHub מחובר בסביבה, צריך ליצור מאגר ב-GitHub ולתת כאן את כתובת ה-remote, למשל:

```powershell
git remote add origin https://github.com/USERNAME/maavar-batuach.git
git push -u origin main
```
