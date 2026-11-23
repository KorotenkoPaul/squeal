# Как поставить Squeal на свой iPhone через TestFlight

Этот файл — для владельца. Всё делается с iPhone (в Safari), Mac не нужен.
Приложение собирает и отправляет в Apple сам GitHub — по одной кнопке.

**Что уже готово в коде:** иконка (сова из `design/icon`), экран запуска (цвет приложения), название «Squeal»,
только вертикальный экран, только iPhone, версия 1.0, отметка «своего шифрования нет» (Apple не будет спрашивать про
экспорт при каждой загрузке), описание приватности (ничего не собираем, ничего не отслеживаем), никаких запросов
разрешений (камера, микрофон и т. п. не используются).

**Чего пока нет и что нужно от вас:** платный аккаунт разработчика Apple и ключ, по которому GitHub сможет загружать
сборки от вашего имени. Ниже — по шагам.

> ⚠️ Кнопка отправки ещё **ни разу не запускалась** (аккаунта не было — проверить было не на чем). Первый запуск может
> упасть на мелочи; тогда откройте сессию Claude и напишите «не сработал TestFlight» — в журнале запуска видно причину.

---

## Шаг 1. Аккаунт разработчика Apple (99 $ в год)

1. На iPhone установите приложение **Apple Developer** из App Store.
2. Откройте его → вкладка **Account** → войдите своим Apple ID (на нём должна быть включена двухфакторная защита).
3. Нажмите **Enroll Now** и пройдите шаги: как **Individual** (частное лицо) — так быстрее всего. Понадобятся паспорт
   или права (приложение попросит сфотографировать) и оплата 99 $.
4. Подтверждение обычно приходит на почту за 1–2 дня. Пока его нет, дальше идти нельзя.

## Шаг 2. Завести приложение в App Store Connect

Сначала — «имя-идентификатор» приложения:

1. В Safari откройте `developer.apple.com/account` → **Certificates, IDs & Profiles** → **Identifiers** → синий «+».
2. Выберите **App IDs** → **App** → Continue.
3. Description: `Squeal`. Bundle ID: **Explicit**, впишите ровно `app.squeal.Squeal`.
   - Если Apple скажет, что такой идентификатор занят, впишите другой, например `app.squeal.reader`, и запомните его —
     он понадобится в шаге 4 (пункт «если идентификатор другой»).
4. Галочки ниже не нужны. Continue → Register.

Теперь само приложение:

5. Откройте `appstoreconnect.apple.com` → **Apps** (Приложения) → синий «+» → **New App**.
6. Platform: **iOS**. Name: `Squeal` (если занято — любое свободное, например `Squeal Stories`; название на экране
   телефона всё равно останется «Squeal»). Primary Language: English (U.S.). Bundle ID: выберите из списка тот, что
   создали. SKU: `squeal1`. User Access: Full Access. → **Create**.

## Шаг 3. Ключ для GitHub (App Store Connect API key)

1. В `appstoreconnect.apple.com` → **Users and Access** (Пользователи и доступ) → вкладка **Integrations**
   (Интеграции) → **App Store Connect API** → **Team Keys**.
2. Если просят — нажмите **Request Access** и согласитесь с условиями.
3. Нажмите «+» (Generate API Key). Name: `GitHub`. Access: **Admin**. → Generate.
4. На этой странице теперь три вещи, которые понадобятся:
   - **Issuer ID** — длинная строка с дефисами над таблицей;
   - **Key ID** — 10 символов в строке ключа;
   - кнопка **Download** — скачивает файл `AuthKey_XXXXXXXXXX.p8`. **Скачать можно только один раз.** Сохраните его в
     «Файлы» на iPhone.
5. Ещё нужен **Team ID**: `developer.apple.com/account` → **Membership details** → строка «Team ID» (10 символов).

> 🔒 Файл `.p8` — это ключ от вашего аккаунта разработчика. **Никогда не присылайте его содержимое в чат с Claude,
> не кладите в репозиторий, не отправляйте в мессенджерах.** Он вставляется только в «секреты» GitHub (шаг 4) — оттуда
> его не может прочитать никто, даже вы сами. Если ключ куда-то утёк — на той же странице нажмите Revoke и создайте
> новый.

## Шаг 4. Положить ключ в секреты GitHub

1. В Safari откройте `github.com/KorotenkoPaul/squeal` (войдите в свой аккаунт GitHub). Если страница в мобильном
   виде не показывает настройки — нажмите «аА» в адресной строке → «Запросить настольный веб-сайт».
2. **Settings** → слева **Secrets and variables** → **Actions** → вкладка **Secrets** → **New repository secret**.
3. Создайте по очереди четыре секрета (имя вписывать точно так, заглавными):

   | Name | Что вставить в Secret |
   |---|---|
   | `ASC_KEY_ID` | Key ID (10 символов) |
   | `ASC_ISSUER_ID` | Issuer ID (длинная строка с дефисами) |
   | `APPLE_TEAM_ID` | Team ID (10 символов) |
   | `ASC_KEY_P8` | Весь текст файла `.p8`: откройте файл в «Файлах», выделите всё — от строки `-----BEGIN PRIVATE KEY-----` до `-----END PRIVATE KEY-----` включительно — скопируйте и вставьте |

   Если «Файлы» не показывают текст файла `.p8`: удерживайте файл → «Поделиться» → «Скопировать», либо откройте его
   в любом текстовом редакторе.
4. **Только если идентификатор другой** (не `app.squeal.Squeal`): там же вкладка **Variables** → **New repository
   variable** → Name `BUNDLE_ID`, Value — ваш идентификатор.

## Шаг 5. Отправить сборку

1. `github.com/KorotenkoPaul/squeal` → вкладка **Actions** → слева **testflight** → справа **Run workflow**.
2. Branch: `master`. Version: `1.0` (при следующих отправках можно оставлять ту же или поднимать: 1.1, 1.2…) →
   зелёная кнопка **Run workflow**.
3. Через 15–25 минут рядом с запуском появится зелёная галочка — сборка ушла в Apple. Красный крестик — см. ниже.
   (То же самое может сделать Claude по просьбе «отправь в TestFlight» — кнопку он нажмёт сам, ключ ему для этого
   не нужен.)

## Шаг 6. Поставить на iPhone

1. Установите приложение **TestFlight** из App Store.
2. `appstoreconnect.apple.com` → Apps → Squeal → вкладка **TestFlight**. Через 5–20 минут после зелёной галочки там
   появится сборка (сначала «Processing»).
3. Слева **Internal Testing** → «+» → назовите группу (например `Me`) → Create → в группе **Testers** «+» → отметьте
   себя → Add. Сборка добавится в группу сама (галочка «Enable automatic distribution»).
4. На почту придёт приглашение — откройте его на iPhone → **View in TestFlight** → **Install**.
   Дальше каждая новая сборка будет приходить в TestFlight сама, с уведомлением.
5. Чтобы дать приложение ещё кому-то (до 100 человек без проверки Apple): Users and Access → «+» → добавьте человека
   с ролью Developer или Marketing → потом добавьте его в ту же группу.

Сборка в TestFlight живёт 90 дней; потом просто отправьте новую (шаг 5).

---

## Что проверить руками в первую очередь (на настоящем iPhone этого проверить было нельзя)

1. **Главная, жанры (баг №52):** потяните главную вниз 5–10 раз на разных жанрах — надпись жанра и овал не должны
   мигать или пропадать ни разу.
2. **Овал жанров и слайдер:** ведите овал (или слайдер) вбок и по дуге вниз — страница под пальцем не должна ехать;
   чуть сдвиньте овал вбок, потом вниз — овал не прыгает назад, обновление не начинается.
3. **Сова и рулетка:** обновление сверху (в т. ч. держа палец после моргания); рулетка снизу — медленно, быстро,
   20–30 коротких рывков подряд, перетянуть и вернуть вниз. Бросок страницы в край — пружинит как обычно.
4. **Чат:** быстрые тапы, длинная переписка — ничего не дёргается; голосовое и кружок играют, звук останавливается
   при выходе; свайп назад от левого края; быстрые переключения частей 1 → 2 → 1.
5. **Двойные нажатия:** карточка, ✕, «Читать», «Читать заново», «Вернуться к выбору» — второе нажатие ничего лишнего
   не нажимает, а обычные нажания не теряются.
6. **Вибрация:** лайк и снятие лайка — короткая; удержание «начать заново» — нарастающая.
7. **Избранное:** удаление нижней истории в длинном списке — без рывка.
8. **Настройка «Уменьшение движения»** (Настройки → Универсальный доступ → Движение): приложение работает, ничего не
   летает и не скачет.
9. Самый маленький iPhone (SE) и самый большой — если есть под рукой.

## Если что-то пошло не так

- **«Missing repository secrets»** — не создан или назван с ошибкой один из четырёх секретов (шаг 4).
- **«ASC_KEY_P8 is not the text of a .p8 key file»** — вставлен не весь текст файла (нужны и строки BEGIN/END).
- **«No suitable application records were found»** или **«bundle identifier»** — приложение не создано в App Store
  Connect (шаг 2) или идентификатор отличается (шаг 4, пункт 4).
- **«Cloud signing permission error»**, **«No signing certificate»** — ключ создан не с ролью **Admin** (шаг 3) или
  не принято новое соглашение Apple (зайдите на `developer.apple.com/account` — сверху будет жёлтая плашка
  «Review Agreement»).
- **«The bundle version must be higher»** — запустите ещё раз: номер сборки растёт сам с каждым запуском.
- Что угодно другое — напишите Claude «не сработал TestFlight»: он откроет журнал запуска и поправит.

## Для разработчика (English)

- Workflow: `.github/workflows/testflight.yml` (`workflow_dispatch` only, from `master`). Secrets: `ASC_KEY_ID`,
  `ASC_ISSUER_ID`, `ASC_KEY_P8` (the .p8 text, or its base64), `APPLE_TEAM_ID`; optional variable `BUNDLE_ID`.
- It runs the unit tests, archives Release **unsigned** (`CODE_SIGNING_ALLOWED=NO`), then
  `xcodebuild -exportArchive -allowProvisioningUpdates -authenticationKey…` with `method app-store-connect`,
  `destination upload`, `signingStyle automatic`: Xcode signs with the team's cloud-managed distribution certificate
  and an App Store profile it creates itself. No certificate or profile files, no registered device needed.
  Version = the input; build number = `GITHUB_RUN_NUMBER`.
- **Untested** (no developer account existed when it was written). If export refuses an unsigned archive, the
  fallback is a signed archive: drop the three `CODE_SIGN…` overrides, add `CODE_SIGNING_ALLOWED=YES
  CODE_SIGN_STYLE=Automatic` and the same `-allowProvisioningUpdates -authenticationKey…` flags to the archive step
  (that path needs one device registered in the account, for the development profile Xcode then wants).
- App settings live in `ios/project.yml` (bundle id, version, portrait, iPhone only, `ITSAppUsesNonExemptEncryption`),
  `ios/Support/Info.plist` (launch screen colour), `ios/Squeal/Assets.xcassets` (icon from
  `design/icon/squeal-icon-1024.png`, alpha removed; `LaunchBackground`), `ios/Squeal/PrivacyInfo.xcprivacy`
  (UserDefaults, reason CA92.1; no tracking, no collected data).
- Before a public App Store release (not needed for TestFlight): the demo subscription switch in Menu and
  `Store.premium` defaulting to `true` must give way to real StoreKit purchases; "Restore purchases", "Suggest a
  story" and "Email support" are still toasts; App Store screenshots, description, age rating (horror: likely 12+ or
  17+), privacy policy URL.
