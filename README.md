# عُواء القمر · Moonhowl

لعبة خداع اجتماعي (ذئاب وقرويون) تعمل **بدون إنترنت** على شبكة الواي فاي المحلية.
أحد اللاعبين يفتح غرفة من هاتفه، والباقون ينضمون من هواتفهم على نفس الشبكة.
لا حسابات ولا تسجيل دخول: الملف الشخصي محفوظ على الجهاز فقط.

A local-Wi-Fi social deduction game for Android and iOS. One phone hosts, everyone
else joins from their own phone. No internet, no accounts.

## المزايا

- **ملف شخصي محلي:** اسم، صورة رمزية (إيموجي ولون أو صورة)، وإحصائيات (ألعاب، انتصارات، الدور الأكثر).
- **استضافة على الهاتف:** هاتف المضيف يشغّل الخادم بنفسه، لا حاجة لأي جهاز آخر.
- **الانضمام:** الغرف تظهر تلقائيًا على نفس الشبكة، أو بمسح رمز QR، أو بكتابة العنوان.
- **الأدوار:** قروي، ذئب، العرّافة، الحارس، الساحرة، الصياد، العمدة، المهرّج.
- **توزيع تلقائي متوازن** حسب عدد اللاعبين، أو يختار المضيف الأدوار بنفسه.
- **مراحل اللعب:** ليل ← (الساحرة) ← نهار ونقاش ← تصويت ← (طلقة الصياد) مع مؤقت لكل مرحلة.
- **الراوي:** راوٍ تلقائي يكتب ما يحدث ويوجّه كل لاعب حسب دوره، أو يكون المضيف راويًا بدون دور.
- **ما يراه كل لاعب:** دورك فقط، والذئاب يرون بعضهم، والأدوار تُكشف عند الموت (اختياري)، والموتى يرون كل شيء (اختياري).
- **الدردشة:** ساحة القرية، وكر الذئاب (سري)، المقبرة (للموتى)، رسائل خاصة، ومجموعات يُنشئها اللاعبون.
- **أدوات المضيف:** إيقاف مؤقت، تخطي المرحلة، قفل الغرفة، كلمة سر، إخراج لاعب.
- **إعادة اتصال تلقائية:** إذا انقطع الواي فاي يرجع اللاعب لنفس مقعده ودوره.
- **الأجواء:** أصوات لليل والنهار والموت، اهتزاز عند دورك، واجهة ليلية داكنة، عربي (من اليمين لليسار) وإنجليزي.

## البنية (Monorepo)

```
apps/mobile/          تطبيق Flutter (Android + iOS)
packages/howl_core/   قواعد اللعبة: الأدوار، المراحل، التصويت، الفوز، صلاحيات الدردشة، البروتوكول (Dart فقط)
packages/howl_net/    الخادم والعميل عبر WebSocket على الشبكة المحلية (dart:io فقط)
tool/check.sh         تحليل واختبار كل الحزم
```

The repo is a [pub workspace](https://dart.dev/tools/pub/workspaces): one `flutter pub get`
at the root resolves every package.

- `howl_core` holds the only copy of the rules. It is pure Dart with an injected
  clock, so the whole game is unit-tested without a phone.
- `howl_net` runs on the host's phone: an `HttpServer` with a WebSocket endpoint
  (`/ws`) and a status endpoint (`/info`). Every player, the host included, connects
  as a client and receives a view filtered to what their role may know.
- `apps/mobile` is the UI. Rooms are announced with Bonjour/NSD (`_moonhowl._tcp`)
  and shared as a QR code (`moonhowl://<ip>:<port>`).

## التشغيل

المتطلبات: Flutter 3.47 أو أحدث.

```bash
flutter pub get
cd apps/mobile
flutter run            # على هاتف أو محاكي متصل
```

- **Android:** `flutter build apk --release`
- **iOS:** يحتاج جهاز Mac مع Xcode: `cd apps/mobile && flutter build ios` ثم التوقيع من Xcode.

الاختبارات:

```bash
./tool/check.sh
```

## ملاحظات

- يجب أن يبقى تطبيق المضيف مفتوحًا أثناء اللعب، فاللعبة كلها تعمل من هاتفه (الشاشة تبقى مضاءة تلقائيًا).
- على iOS يطلب النظام إذن "الشبكة المحلية" في أول مرة؛ يجب الموافقة عليه للاستضافة والانضمام.
- يمكن استخدام نقطة اتصال (Hotspot) هاتف المضيف بدل الراوتر.
- إذا لم تظهر الغرفة في القائمة (بعض الشبكات تمنع الاكتشاف)، استخدم رمز QR أو اكتب العنوان الظاهر عند المضيف.
