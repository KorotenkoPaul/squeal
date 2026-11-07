# Squeal (2018) — что это и как устроено

Сводка по старому iOS-приложению, скопированному с Google Drive в `/home/user/squeal/legacy/`. Список файлов — в `INVENTORY.md`.

## Коротко, простыми словами

**Squeal** — iPhone-приложение с «историями в переписке» (chat fiction). Каждая история выглядит как чат двух персонажей в мессенджере. Читатель тапает по экрану, и появляется следующее сообщение. Жанры: ужасы, триллер, романтика. Языки: английский и французский, переключаются в меню.

- **Где лежат истории.** Тексты историй в приложение не встроены. Они хранились на сервере Google Firebase (облачная база данных), картинки к ним — в облачном хранилище Firebase. Приложение скачивало всё при запуске, а без интернета показывало «You're offline».
- **Исходники историй** лежат на Drive в Word (.docx): 22 английские и 21 французская. Скорее всего, это единственная сохранившаяся копия, потому что сервер Firebase мог давно отключиться (это не проверялось).
- **Деньги.** Бесплатно можно сделать около 100 тапов, дальше нужно ждать или купить подписку «Squeal Unlimited»: 3 дня бесплатно, затем $3.99 в неделю, $11.99 в месяц или пакет на 6 месяцев. Покупки шли через App Store.
- **Состояние проекта.** Код 2018 года (Swift 4, iOS 11). В таком виде его не собрать в нынешнем Xcode, и App Store его не примет. Для перезапуска приложение проще написать заново, а тексты историй, обложки и иконки взять из этой папки.

## Экраны и сценарий (по коду и `Main.storyboard`)

1. **Заставка** (`LaunchScreen.storyboard`): логотип «squeal» на тёмно-фиолетовом фоне.
2. **Нижняя панель вкладок** (`CustomTabBarController`, при старте открывается средняя вкладка):
   - **Главная** (`MainViewController`). Сверху крутится карусель «BEST OF THE WEEK / MEILLEUR DE LA SEMAINE» (`HeaderView`, `AutoScrolling`, она меняет историю каждые 3 секунды). Ниже переключатель жанров FEATURED · HORROR · ROMANCE · THRILLER (`GenreSwitcher`) и сетка карточек историй с обложкой, названием, рейтингом и числом просмотров. Пока данные грузятся, вместо карточек видны серые заглушки (`LoadingDataSource`). Долгое нажатие на карточку добавляет её в избранное.
   - **Поиск** (`SearchViewController`): поиск по названию и список всех историй по жанрам.
   - **Избранное** (`FavouritesViewController`): сохранённые истории с процентом прочитанного («Completed 40%»). Свайп влево открывает кнопку Remove.
3. **Чат-история** (`MessengerViewController`, сегвеи `openMessenger…`). Сообщения левого и правого персонажа появляются по одному на каждый тап, телефон слегка вибрирует. Если в тексте сообщения есть ссылка `http`, вместо текста показывается картинка. Если у истории несколько эпизодов, внизу есть кнопки 1/2/3 (`EpisodePicker`). В конце читатель ставит оценку от 1 до 5 звёзд. Оценки и просмотры записываются в Firebase. Когда бесплатные тапы кончаются, включается таймер ожидания или предлагается подписка.
4. **Меню** (`MenuViewController`): Subscription, Language (English/Français), Rate the App, Share the App (ссылка на App Store id1388990468), Restore Purchases, Leave Feedback (письмо на почту поддержки), Suggest a Story («за каждую опубликованную историю — $20»).
5. **Подписка** (`SubscriptionViewController`, сегвей `showPay`): три тарифа, окно закрывается свайпом вниз.
6. **Политика конфиденциальности** (`PrivacyPolicyViewController`) открывает встроенный `PrivacyPolicy.pdf`.

## Истории

**Сводная таблица автора** (`Summary.pages`, лето 2018): «Summary of Stories (21)». У всех историй, кроме «The crossroad» (она «translating»), стоит пометка «translated — uploaded (en, fr)». Ещё одна, «Headache», числится «in revision», но файла с ней на Drive нет. Число в скобках, например «(9)», похоже на внутреннюю оценку истории.

**Английские** (`Stories For Squeal/Stories/`, 22 истории и 2 сводки «Summary of chats»):

| Автор (папка) | История | Сюжет одной строкой |
|---|---|---|
| Rick (Rich Samuels), horror | Haunted (9) | Двое друзей на спор за $200 ночуют в доме с привидениями. |
| | First Impressions (8) | Девушка знакомит нового парня с семьёй; у семьи «особый вкус». |
| | The Doctor (8) | Раненый турист в глуши получает по переписке «советы врача». |
| | Skinless (7) | Парень сдирает корочку с раны без боли и не может остановиться. |
| | Nobody's home Part 1 (9) | Патрик приходит на вечеринку, а в доме темно и пусто. |
| | Nobody's home Part 2 (10) | Дома так же пусто; друг стоит рядом, но они не видят друг друга. |
| | Nobody's home Part 3 (7) | Патрик не верит, что мёртв, и возвращается разоблачить «розыгрыш». |
| Rick, thriller | Last Train Out (9) | Пара бежит из страны во время революции, на границе досмотр. |
| | Grave (8) | Незнакомая девушка пишет, что её закопали заживо в гробу. |
| | Reunion (7) | Встреченный одноклассник, приглашённый на вечеринку, оказывается серийным убийцей. |
| | Clown (10) | Человеку, который боится клоунов, пишет злой клоун Zippo. |
| | Slice (9) | Серийный убийца сообщает Колину, что тот следующий. |
| | Unwanted Guest (8) | Ночью Шэрон находит дверь открытой: в доме кто-то есть? |
| Asjad Ullah, horror | Love till Death (10) | У Джейка пять минут до смерти и признание, которое могло бы его спасти. |
| Asjad Ullah, romance | Perfect Match* | Муж на сайте знакомств находит «идеальную пару», и это его собственная жена. |
| | Clinical Love* | Психиатр влюблён в пациентку, а на самом деле пациент он. |
| | Frenemy* | Сестра помогает выследить изменяющего мужа и выдаёт, что любовница — она. |
| | The Crushing Love* | Хенна признаётся лучшему другу Бену в романе с женатым Гарри, а «жена» Гарри — это Бен. |
| | The crossroad (7) | Жена подставляет мужа-миллионера ради брачного контракта; все обманывают всех. |
| Patricia Johnson, romance | The Reunion Affair* | Бывшие возлюбленные встречаются на встрече выпускников, но он погиб на войне. |
| | Mystery Girlfriend 2 (10) | Сын миллиардера влюбился в девушку из Facebook; отец против, и не зря. |
| Rutaba Shahzad, thriller | Under wrong hands* | Женщину обвиняют в убийстве мужа; подруга-соседка оказывается настоящей убийцей. |

\* Английский .docx не скачан. Сюжет взят из французской версии.

**Французские** (`Stories For Squeal/Histoires/`, 21 история): Horreur — Haunted, First Impressions, The Doctor, Skinless, Nobody's home 1–3, Love till Death (8); Thriller — Last Train Out, Grave, Reunion, Clown, Slice, Unwanted Guest, Under wrong hands (7); Romance — Reunion Affair, Mystery Girlfriend, Clinical Love, Frenemy, Perfect Match, Crushing Love (6). Нет только «The crossroad».

**Медиа.** Аудио и видео нет ни в коде, ни в файлах. Есть только картинки: обложки историй (в Firebase Storage, полноразмерные копии в «Messed images», около 200 МБ) и картинки внутри чата (в .docx отмечены строками вида «PIC: EXTERIOR OF HAUNTED HOUSE», в приложении подставлялись по ссылке).

## Что в трёх документах

- **Summary.pages**: статус каждой истории (переведена, есть картинка, загружена, куда выводится: SLIDER/FEATURED). Пять триллеров помечены «move to Horror».
- **Server.pages**: рабочий «скрипт загрузки» на Swift для каждой истории. Это кусок кода с массивами реплик и вызовы `ref.child("story/…").setValue(...)` и `ref.child("ganres/…").setValue(...)`, которыми автор вручную заливал истории в Firebase. Заголовок «20 fr — 9 eng» похож на счётчик загруженного. Это единственное место, где видно точную структуру данных на сервере (см. ниже).
- **My personal ideas.docx**: черновые идеи новых историй. Например: девушка прячется под кроватью и фотографирует ноги чужака; пропавший друг присылает «селфи», а это отрезанная голова; похищенная пишет подруге с телефона похитителя; одноклассник-убийца приходит раньше времени; богатый сын влюбляется в девушку из Facebook. Последняя идея стала «Mystery Girlfriend».

---

## Технический раздел

| Параметр | Значение |
|---|---|
| Язык | Swift 4.0 (`SWIFT_VERSION = 4.0`), UIKit + Storyboard; Objective-C в своём коде нет |
| Xcode | проект `Squeal.xcodeproj` + `Squeal.xcworkspace` (CocoaPods), `LastUpgradeCheck = 0940` (Xcode 9.4), objectVersion 48 |
| iOS deployment target | 11.0 (проект) / 11.4 (таргет); только iPhone (`TARGETED_DEVICE_FAMILY = 1`), только портрет, `armv7` в required capabilities |
| Bundle ID | `com.pauldevelopers.ios` (в pbxproj). В `GoogleService-Info.plist` указан другой: `com.apprt.pauldevelopers.Squeal`, то есть они не совпадают |
| Версия | 1.0 (build 12); App Store id 1388990468 (из ссылки «Share») |
| Последние правки | pbxproj 21.01.2019, `MessengerViewController.swift` 09.02.2019, остальное в основном октябрь 2018 |
| Авторы в заголовках | Paul Korotenko, а также Vlad Zaitsev, Yaroslav Morgachev, p.ilin («PaulDevelopersGroupe»); комментарии частично на русском |

**Зависимости (Podfile / Podfile.lock, CocoaPods 1.6.0.beta.1):**

| Pod | Версия | Зачем |
|---|---|---|
| Firebase/Core (+FirebaseAnalytics 5.0.1, InstanceID) | 5.2.0 | инициализация Firebase (`FirebaseApp.configure()`); аналитика подключена транзитивно, в коде не вызывается |
| Firebase/Database (FirebaseDatabase 5.0.1, leveldb) | 5.2.0 | **основное хранилище историй**, меню жанров, слайдера, просмотров и рейтингов (Realtime Database) |
| Firebase/Storage (FirebaseStorage 3.0.0, GTMSessionFetcher) | 5.2.0 | загрузка обложек (`Storage.storage().reference().child(image).getData`) |
| SVProgressHUD | 2.2.5 | индикатор загрузки и успеха/ошибки покупки |
| SwiftyStoreKit | 0.13.3 | подписки: покупка, восстановление, проверка чека |

Firebase Auth нет: вход не нужен, в базу пишут все анонимно.

**Как грузятся данные** (`StoryDatasource.swift`, `MainViewController.changeStoryFromServer`):
1. Подписка на `.info/connected`. Без сети показывается экран «offline».
2. `conversion` содержит просмотры и рейтинг каждой истории: `{ "<name>": { "views": {"num": N}, "rating": {"num": X} } }`. Обновляется транзакциями при каждом открытии и оценке.
3. `ganres/{featuredMenu|horrorMenu|romanceMenu|thrillerMenu}/{eng|fr}/<name>` содержит карточку истории в виде массива `[название, описание (~185 символов), автор, дата "MMMM dd, yyyy", статус, жанр, путь_к_картинке_в_Storage, (опц.) [эпизоды]]`.
4. `story/{horrorStory|romanceStory|thrillerStory}/{eng|fr}/<name в нижнем регистре>` содержит сам чат (формат ниже). Время чтения считается как `scheme.count × 5 сек`.
5. `slider` хранит список картинок для карусели; истории сопоставляются по пути картинки.
6. Локально в `UserDefaults` хранятся язык (`Languages`), избранное (`Favourite`, NSKeyedArchiver), прогресс по каждой истории, счётчик бесплатных тапов (`Taps`, лимит 100, сбрасывается по времени) и флаг подписки.

**Формат истории** (из `Server.pages` и `StoryDatasource.swift`): реплики двух собеседников лежат в двух массивах, порядок задаёт массив `scheme`:

```swift
// путь: story/romanceStory/eng/the crushing love
["forLeft":  ["Hi Henna, I am fine.", "What about you?", "Nothing much.", ...],   // реплики левого (Ben)
 "forRight": ["Hi Ben how are you doing?", "I am fine too.", "So what's up?", ...], // реплики правого (Henna)
 "middle":   ["Ben", "Henna"],                  // имена: [левый, правый]
 "scheme":   ["R","L","L","R","R","L", ...]]    // кто говорит следующим
// карточка: ganres/romanceMenu/eng/the crushing love
["The Crushing Love", "Henna confides in her best friend Ben…", "Asjad Ullah",
 "17 September", "ok", "romance", "images/romance/the crushing love.jpg"]
```
Сообщение, в тексте которого есть `http`, выводится как картинка. В .docx истории записаны как «Имя: реплика» (или таблица из двух колонок) с шапкой Title/Author/Description, поэтому конвертировать их в этот формат несложно.

**Что устарело или сломано, что мешает App Store сегодня:**
- `UIWebView` в `PrivacyPolicyViewController`. С 2020 года App Store отклоняет приложения с UIWebView.
- `UIApplication.shared.value(forKey: "statusBar")` (KVC к приватному status bar, используется в 5+ экранах) на iOS 13+ приводит к падению приложения.
- Swift 4.0, iOS 11, armv7, Xcode 9.4. Текущий Xcode требует более новый минимальный iOS (12+) и arm64. `kCAFillModeForwards` и другие API времён Swift 4 потребуют миграции.
- Firebase 5.x (2018) не собирается современным Xcode. Нужен Firebase 10+/11+ через Swift Package Manager. CocoaPods вообще стоит заменить на SPM: репозиторий CocoaPods trunk объявлен read-only, по данным на момент написания — с конца 2026 года, это стоит перепроверить.
- Нет Privacy Manifest (`PrivacyInfo.xcprivacy`), обязательного с 2024 года. Нет экрана и ссылки на Terms of Use и EULA, которые App Store требует для подписок. На экране подписки цены захардкожены, а не взяты из StoreKit (`localizedPrice` получают, но не используют).
- Проверка чека App Store идёт прямо из клиента с общим секретом (`AppleReceiptValidator` с verifyReceipt). Apple считает этот способ устаревшим, сейчас используют StoreKit 2.
- В `GoogleService-Info.plist` стоит `IS_ADS_ENABLED = true` и тестовые AdMob ID, но рекламного SDK в проекте нет. Bundle ID в plist и в проекте разные.
- Вёрстка с ручными расчётами под конкретные экраны (`UIScreen.main.bounds.height == 568`), без учёта «чёлки» и Dynamic Island.
- Много глобальных переменных и опечаток в ключах (`ganres`, `MessangerCell`, `reloadGenreSwircher`). `requestReview` вызывается через `AppDelegate()` (создаётся новый экземпляр). Есть пустая модель Core Data (`Squeal.xcdatamodeld`). `File.swift` дублирует классы `GenreButton`/`GenreSwitcher` (вероятно, исключён из таргета). Сборку не проверяли.
- Серверная часть (Firebase-проект) могла быть удалена или заморожена; правила доступа к базе неизвестны. Тексты историй на Drive в .docx/.pages — надёжный источник.

**Секреты и ключи** (только где лежат, значения не приводятся):
- `Squeal App/Squeal App/Squeal/Supporting Files/Misc/GoogleService-Info.plist`: Firebase API key, client ID, project ID, Database URL, Storage bucket, AdMob test unit IDs.
- `Squeal App/Squeal App/Squeal/AppDelegate.swift` и `Squeal App/Squeal App/Squeal/Controllers/MenuViewController.swift`: захардкожен App Store **shared secret** для проверки подписок (в двух местах). Если приложение будут перезапускать, этот секрет стоит сменить в App Store Connect.
- `Stories For Squeal/Server.pages` (`Server.txt`): ключей нет, только пути Firebase.
- Development Team ID есть в `project.pbxproj`, но он не секретный.
- В репозиторий/коммит эти файлы класть нельзя без очистки.
