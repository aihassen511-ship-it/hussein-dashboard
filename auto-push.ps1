# 🤖 Hussein Dashboard Auto-Push System
# يعمل تلقائياً عند تعديل أي ملف
# ============================================

# الانتقال للمجلد
Set-Location "C:\Users\Administrator\.openclaw\workspace\dashboard"

Write-Host "🤖 فحص التغييرات..." -ForegroundColor Cyan

# التحقق من وجود تغييرات
$status = git status --porcelain

if ($status) {
    Write-Host "🔄 تم العثور على تغييرات جديدة!" -ForegroundColor Yellow
    Write-Host ""
    
    # عرض الملفات المتغيرة
    Write-Host "الملفات المعدلة:" -ForegroundColor White
    git status --short | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
    
    # إضافة كل الملفات
    git add -A | Out-Null
    
    # إنشاء رسالة Commit
    $changedFiles = git diff --cached --name-only
    $fileCount = ($changedFiles | Measure-Object).Count
    
    # تحديد نوع التغيير
    if ($changedFiles -match "data.json") {
        $commitMsg = "📊 Auto: Skills data updated ($fileCount files)"
    }
    elseif ($changedFiles -match "index.html") {
        $commitMsg = "🎨 Auto: Website updated ($fileCount files)"
    }
    elseif ($changedFiles -match "\.md$") {
        $commitMsg = "📚 Auto: Documentation updated ($fileCount files)"
    }
    elseif ($changedFiles -match "\.mq5$") {
        $commitMsg = "🏆 Auto: Trading bot updated ($fileCount files)"
    }
    else {
        $commitMsg = "🔄 Auto: $fileCount files updated"
    }
    
    Write-Host "💾 Commit: $commitMsg" -ForegroundColor Yellow
    git commit -m "$commitMsg" | Out-Null
    
    # Push
    Write-Host ""
    Write-Host "☁️ رفع التغييرات على GitHub..." -ForegroundColor Cyan
    git push origin main 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ تم الرفع بنجاح!" -ForegroundColor Green
        Write-Host "🌐 الموقع سيتحدث خلال 2-5 دقائق" -ForegroundColor Green
        Write-Host ""
        Write-Host "🔗 https://aihassen511-ship-it.github.io/hussein-dashboard" -ForegroundColor Cyan
    }
    else {
        Write-Host ""
        Write-Host "❌ فشل الرفع - قد تحتاج تسجيل دخول" -ForegroundColor Red
    }
}
else {
    Write-Host "✅ لا توجد تغييرات - كل شي محدث!" -ForegroundColor Green
}

Write-Host ""
Write-Host "⏱️ تم التنفيذ في: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
