# macOS State

[![CI](https://github.com/sadikihicham/macos-state/actions/workflows/ci.yml/badge.svg)](https://github.com/sadikihicham/macos-state/actions/workflows/ci.yml)

[English](README.md) · [Français](README.fr.md) · **العربية**

مُراقِب لنظام macOS يظهر كـ **واجهة عرض عائمة (HUD) على سطح المكتب** (شبيه بمراقب النشاط
Activity Monitor، لكنه أكثر تحفّظًا ومرئيٌّ دائمًا). يعرض المعالج · الذاكرة · القرص · البطارية ·
الشبكة كنِسَب استخدام، مع **وضع مُصغّر** (مقاييس) ⇄ **وضع مُوسّع** (تفاصيل + قائمة بالعمليات
النشطة مع إمكانية **إنهاء** عملية/تطبيق).

تطبيق أصلي بـ **Swift + SwiftUI/AppKit**. محلي 100٪، **بدون أي وصول إلى الشبكة** (مضمون باختبار).

## الميزات

- **واجهة HUD على سطح المكتب**: شفافة، قابلة للسحب، تتذكّر موضعها؛ مُصغّر ⇄ مُوسّع.
- **المقاييس**: المعالج (+ لكل نواة)، الذاكرة (نشطة/مثبّتة/مضغوطة/حرة)، القرص (مستخدَم/حر/إجمالي)،
  البطارية (٪، الشحن، الوقت المتبقي، **الدورات + الصحة**)، الشبكة (معدّل ↓/↑ إجمالي + **لكل واجهة**),
  **الحرارة (المعالج) + سرعة المروحة** (أفضل جهد؛ «N/A» إن لم تتوفّر).
- **العمليات** (الوضع المُوسّع): أعلى المستهلكين للمعالج/الذاكرة، أيقونة، **زر إنهاء** مع تأكيد.
- **أيقونة في شريط القوائم** (بجوار الساعة): إظهار/إخفاء الواجهة، دائمًا في المقدمة، الفاصل الزمني،
  المقاييس، التشغيل عند تسجيل الدخول، إنهاء.
- **الإعدادات**: فترة التحديث (1/2/5 ثوانٍ)، المقاييس المعروضة، التشغيل عند تسجيل الدخول.

## نموذج الأمان

- **بدون شبكة إطلاقًا**: مراقب محلي بحت. مُتحقَّق منه بـ `make check-net` (يفشل إذا رُبط أي
  إطار/رمز شبكة صادر).
- **إنهاء مُقيّد ومحروس** (`KillGuard`، دالة نقية مُختبَرة):
  - عمليات **المستخدم الحالي** فقط (`uid == getuid()`)، دون رفع للصلاحيات؛
  - **يرفض** معرّفات العمليات المحجوزة (≤1)، والمراقب نفسه، و**الملفات التنفيذية للنظام**
    (مسار تحت `/System`، `/usr/libexec`، `/usr/sbin`…)، و**قائمة حظر** للخدمات الحرجة
    (launchd، WindowServer، loginwindow، cfprefsd، tccd، coreaudiod…)؛
  - **رفض افتراضي عند الشك (fail-closed)**: هوية غير مقروءة → رفض؛
  - **حماية من إعادة استخدام معرّف العملية**: يُعاد التحقق من الهوية (uid + وقت البدء بدقّة
    **µs**) قبل التنفيذ مباشرةً وقبل التصعيد إلى `SIGKILL`؛
  - **تأكيد بشري** إلزامي (NSAlert)؛ ثم `SIGTERM` يتبعه `SIGKILL` بعد مهلة.
- **خارج صندوق الحماية (non-sandboxed)** (إنهاء العمليات غير متوافق مع App Sandbox)، صلاحيات
  دنيا، بلا أسرار، ولا كتابة خارج `UserDefaults`.

## البناء والتشغيل

المتطلبات: macOS 14+، Xcode/Swift 6.

```bash
make run            # build + launch the HUD (dev)
make test           # unit tests (pure SystemMetrics lib)
make accuracy       # accuracy eval: samplers vs system sources (sysctl/vm_stat/df/pmset/ifconfig)
make check-net      # fitness function: proves there is no network capability
make verify         # test + check-net (full gate)
make hooks          # enable the versioned git hooks (run once after cloning)
```

## التوزيع

```bash
make dmg            # distributable .dmg: UNIVERSAL app (arm64 + x86_64), ad-hoc signed
make notarize       # Developer ID signed + notarized .dmg (no Gatekeeper warning; needs an
                    #   Apple Developer account — reads DEV_ID and NOTARY_PROFILE from the env)
make bundle         # ad-hoc signed .app (.build/MacOSState.app)
make install-agent  # LaunchAgent: start at login (personal use)
```

مُخرَج `make dmg` **موقَّع ad-hoc** (غير مُصدَّق/Notarized): على جهاز Mac آخر، يُحجب التشغيل الأول
بواسطة Gatekeeper. للتجاوز: انقر بزر الفأرة الأيمن على التطبيق → **فتح** → فتح، أو
`xattr -dr com.apple.quarantine "/Applications/MacOSState.app"`. للتوزيع دون أي تحذير، استخدم
`make notarize` (يتطلّب حساب Apple Developer).

## البنية

```
Sources/
  SystemMetrics/      # PURE & testable core (no UI)
    CPUSampler · MemorySampler · DiskSampler · BatterySampler · NetworkSampler
    ProcessLister · KillGuard · Models (pure functions)
  MacOSStateApp/      # AppKit + SwiftUI
    main · AppDelegate (menu bar + confirmations) · DesktopPanel (desktop NSPanel)
    MetricsEngine (timer → snapshot) · ProcessController (kill) · Settings · LaunchAtLogin
    Views/ (HUDView, Gauges, ExpandedDetails, ProcessListView)
Tests/SystemMetricsTests/   # deltas, %, formats, KillGuard, ProcessLister, accuracy
```

كل المنطق (الحسابات، قرار الإنهاء) موجود في `SystemMetrics` على شكل **دوال نقية** ← قابلة
للاختبار دون عتاد. الوصول إلى النظام (mach/IOKit/libproc) معزول داخل وحدات `*Sampler`.

## التحقق الشامل

1. `make verify` ← اختبارات ناجحة + بدون شبكة.
2. `make run` ← قارن المعالج/الذاكرة/القرص/البطارية/الشبكة بـ **مراقب النشاط (Activity Monitor)**.
3. مُصغّر ⇄ مُوسّع؛ يُحفظ الموضع/الحالة بعد إعادة التشغيل.
4. إنهاء آمن: `sleep 1000 &` ← اعثر عليها ← أنهِها ← تختفي؛ عملية نظام (مثل `WindowServer`)
   **غير قابلة للإنهاء** (الزر مُعطَّل / رفض `KillGuard`).
