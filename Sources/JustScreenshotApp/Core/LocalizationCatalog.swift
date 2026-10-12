import Foundation

/// Каталог профессиональных переводов интерфейса Just Screenshot
/// Языки: English (en), Russian (ru), German (de), French (fr), Spanish (es), Chinese (zh-Hans), Japanese (ja)
public enum LocalizationCatalog {
    private static let translations: [String: [AppLanguage: String]] = [
        // MARK: - Menu Bar
        "menu.recording_paused": [
            .english: "Recording paused: %lds",
            .russian: "Запись на паузе: %ldс",
            .german: "Aufnahme pausiert: %lds",
            .french: "Enregistrement en pause : %lds",
            .spanish: "Grabación pausada: %lds",
            .simplifiedChinese: "录屏已暂停：%ld秒",
            .japanese: "録画一時停止中: %ld秒"
        ],
        "menu.recording_active": [
            .english: "Recording in progress: %lds",
            .russian: "Идет запись: %ldс",
            .german: "Aufnahme läuft: %lds",
            .french: "Enregistrement en cours : %lds",
            .spanish: "Grabando: %lds",
            .simplifiedChinese: "正在录屏：%ld秒",
            .japanese: "録画中: %ld秒"
        ],
        "menu.resume_recording": [
            .english: "Resume Recording",
            .russian: "Продолжить запись",
            .german: "Aufnahme fortsetzen",
            .french: "Reprendre l'enregistrement",
            .spanish: "Reanudar grabación",
            .simplifiedChinese: "继续录屏",
            .japanese: "録画を再開"
        ],
        "menu.pause_recording": [
            .english: "Pause Recording",
            .russian: "Приостановить запись",
            .german: "Aufnahme pausieren",
            .french: "Mettre en pause l'enregistrement",
            .spanish: "Pausar grabación",
            .simplifiedChinese: "暂停录屏",
            .japanese: "録画を一時停止"
        ],
        "menu.stop_save_recording": [
            .english: "Stop & Save Recording",
            .russian: "Остановить запись и сохранить",
            .german: "Aufnahme beenden & speichern",
            .french: "Arrêter et enregistrer",
            .spanish: "Detener y guardar grabación",
            .simplifiedChinese: "停止并保存录屏",
            .japanese: "録画を停止して保存"
        ],
        "menu.cancel_recording": [
            .english: "Cancel Recording (Discard)",
            .russian: "Отменить запись (удалить)",
            .german: "Aufnahme abbrechen (verwerfen)",
            .french: "Annuler l'enregistrement (supprimer)",
            .spanish: "Cancelar grabación (descartar)",
            .simplifiedChinese: "取消录屏（丢弃）",
            .japanese: "録画をキャンセル（破棄）"
        ],
        "menu.record_screen": [
            .english: "Record Screen",
            .russian: "Запись экрана",
            .german: "Bildschirm aufnehmen",
            .french: "Enregistrer l'écran",
            .spanish: "Grabar pantalla",
            .simplifiedChinese: "屏幕录制",
            .japanese: "画面録画"
        ],
        "menu.capture_window": [
            .english: "Window Screenshot",
            .russian: "Скриншот окна",
            .german: "Fenster-Screenshot",
            .french: "Capture de fenêtre",
            .spanish: "Captura de ventana",
            .simplifiedChinese: "窗口截图",
            .japanese: "ウィンドウのスクリーンショット"
        ],
        "menu.capture_area": [
            .english: "Area Screenshot",
            .russian: "Скриншот произвольного размера",
            .german: "Bereichs-Screenshot",
            .french: "Capture de zone",
            .spanish: "Captura de área",
            .simplifiedChinese: "自定义区域截图",
            .japanese: "範囲指定スクリーンショット"
        ],
        "menu.repeat_capture": [
            .english: "Repeat Last Capture",
            .russian: "Повторить предыдущий захват",
            .german: "Letzte Aufnahme wiederholen",
            .french: "Répéter la dernière capture",
            .spanish: "Repetir última captura",
            .simplifiedChinese: "重复上次捕获",
            .japanese: "前回のキャプチャを繰り返す"
        ],
        "menu.timed_screenshot": [
            .english: "Timed Screenshot…",
            .russian: "Скриншот с задержкой…",
            .german: "Verzögerter Screenshot…",
            .french: "Capture différée…",
            .spanish: "Captura con temporizador…",
            .simplifiedChinese: "定时截图…",
            .japanese: "タイマースクリーンショット…"
        ],
        "menu.delay_3s": [
            .english: "With 3 Seconds Delay",
            .russian: "С задержкой 3 секунды",
            .german: "Mit 3 Sekunden Verzögerung",
            .french: "Avec 3 secondes de délai",
            .spanish: "Con 3 segundos de retardo",
            .simplifiedChinese: "延迟 3 秒",
            .japanese: "3秒遅延"
        ],
        "menu.delay_5s": [
            .english: "With 5 Seconds Delay",
            .russian: "С задержкой 5 секунд",
            .german: "Mit 5 Sekunden Verzögerung",
            .french: "Avec 5 secondes de délai",
            .spanish: "Con 5 segundos de retardo",
            .simplifiedChinese: "延迟 5 秒",
            .japanese: "5秒遅延"
        ],
        "menu.delay_10s": [
            .english: "With 10 Seconds Delay",
            .russian: "С задержкой 10 секунд",
            .german: "Mit 10 Sekunden Verzögerung",
            .french: "Avec 10 secondes de délai",
            .spanish: "Con 10 segundos de retardo",
            .simplifiedChinese: "延迟 10 秒",
            .japanese: "10秒遅延"
        ],
        "menu.history": [
            .english: "Capture History",
            .russian: "История снимков",
            .german: "Aufnahmeverlauf",
            .french: "Historique des captures",
            .spanish: "Historial de capturas",
            .simplifiedChinese: "截图历史",
            .japanese: "キャプチャ履歴"
        ],
        "menu.open_image": [
            .english: "Open Image…",
            .russian: "Открыть изображение…",
            .german: "Bild öffnen…",
            .french: "Ouvrir une image…",
            .spanish: "Abrir imagen…",
            .simplifiedChinese: "打开图片…",
            .japanese: "画像を開く…"
        ],
        "menu.edit_clipboard": [
            .english: "Edit from Clipboard",
            .russian: "Редактировать из буфера обмена",
            .german: "Aus Zwischenablage bearbeiten",
            .french: "Modifier depuis le presse-papier",
            .spanish: "Editar desde el portapapeles",
            .simplifiedChinese: "从剪贴板编辑",
            .japanese: "クリップボードから編集"
        ],
        "menu.settings": [
            .english: "Settings…",
            .russian: "Настройки…",
            .german: "Einstellungen…",
            .french: "Paramètres…",
            .spanish: "Ajustes…",
            .simplifiedChinese: "设置…",
            .japanese: "設定…"
        ],
        "menu.check_permissions": [
            .english: "Check Screen Recording Permissions",
            .russian: "Проверить разрешения записи экрана",
            .german: "Bildschirmaufnahme-Berechtigungen prüfen",
            .french: "Vérifier les autorisations de capture d'écran",
            .spanish: "Comprobar permisos de grabación de pantalla",
            .simplifiedChinese: "检查屏幕录制权限",
            .japanese: "画面録画のアクセス権を確認"
        ],
        "menu.quit": [
            .english: "Quit",
            .russian: "Выход",
            .german: "Beenden",
            .french: "Quitter",
            .spanish: "Salir",
            .simplifiedChinese: "退出",
            .japanese: "終了"
        ],

        // MARK: - Settings Window
        "settings.title": [
            .english: "Settings",
            .russian: "Настройки",
            .german: "Einstellungen",
            .french: "Paramètres",
            .spanish: "Ajustes",
            .simplifiedChinese: "设置",
            .japanese: "設定"
        ],
        "settings.tab.general": [
            .english: "General",
            .russian: "Основные",
            .german: "Allgemein",
            .french: "Général",
            .spanish: "General",
            .simplifiedChinese: "通用",
            .japanese: "一般"
        ],
        "settings.tab.hotkeys": [
            .english: "Shortcuts",
            .russian: "Горячие клавиши",
            .german: "Tastenkombinationen",
            .french: "Raccourcis",
            .spanish: "Atajos",
            .simplifiedChinese: "快捷键",
            .japanese: "ショートカット"
        ],
        "settings.tab.recording": [
            .english: "Video Recording",
            .russian: "Запись видео",
            .german: "Videoaufnahme",
            .french: "Enregistrement vidéo",
            .spanish: "Grabación de vídeo",
            .simplifiedChinese: "视频录制",
            .japanese: "録画設定"
        ],
        "settings.language.header": [
            .english: "Interface Language",
            .russian: "Язык интерфейса",
            .german: "Sprache",
            .french: "Langue de l'interface",
            .spanish: "Idioma de la interfaz",
            .simplifiedChinese: "界面语言",
            .japanese: "インターフェース言語"
        ],
        "settings.language.description": [
            .english: "Select your preferred language. Changes apply immediately across the entire application.",
            .russian: "Выберите язык интерфейса. Изменения применяются мгновенно во всем приложении.",
            .german: "Wählen Sie Ihre Sprache. Änderungen werden sofort in der gesamten App wirksam.",
            .french: "Sélectionnez votre langue. Les modifications s'appliquent immédiatement.",
            .spanish: "Seleccione su idioma. Los cambios se aplican de inmediato en toda la app.",
            .simplifiedChinese: "选择首选语言。设置将立即应用于整个应用程序。",
            .japanese: "言語を選択してください。変更はアプリ全体に即座に反映されます。"
        ],
        "settings.system.header": [
            .english: "System & Startup",
            .russian: "Система и запуск",
            .german: "System & Start",
            .french: "Système et démarrage",
            .spanish: "Sistema e inicio",
            .simplifiedChinese: "系统与开机启动",
            .japanese: "システムと起動"
        ],
        "settings.launch_at_login": [
            .english: "Launch Just Screenshot at login",
            .russian: "Запускать Just Screenshot при входе в систему",
            .german: "Just Screenshot bei der Anmeldung starten",
            .french: "Lancer Just Screenshot à la connexion",
            .spanish: "Iniciar Just Screenshot al iniciar sesión",
            .simplifiedChinese: "开机时自动启动 Just Screenshot",
            .japanese: "ログイン時に Just Screenshot を起動"
        ],
        "settings.capture.header": [
            .english: "Screenshots",
            .russian: "Скриншоты",
            .german: "Screenshots",
            .french: "Captures d'écran",
            .spanish: "Capturas de pantalla",
            .simplifiedChinese: "截图设置",
            .japanese: "スクリーンショット"
        ],
        "settings.copy_clipboard": [
            .english: "Automatically copy capture to clipboard",
            .russian: "Автоматически копировать снимок в буфер обмена",
            .german: "Aufnahme automatisch in die Zwischenablage kopieren",
            .french: "Copier automatiquement dans le presse-papier",
            .spanish: "Copiar captura automáticamente al portapapeles",
            .simplifiedChinese: "自动将截图复制到剪贴板",
            .japanese: "撮影時にクリップボードへ自動コピー"
        ],
        "settings.play_sound": [
            .english: "Play shutter and recording sound effects",
            .russian: "Воспроизводить звук затвора и записи",
            .german: "Auslöser- und Aufnahmetöne abspielen",
            .french: "Émettre des effets sonores lors des captures et enregistrements",
            .spanish: "Reproducir sonidos de obturador y grabación",
            .simplifiedChinese: "播放快门与录屏提示音效",
            .japanese: "シャッター音と録画効果音を再生"
        ],
        "settings.save_dir.header": [
            .english: "Default Save Directory",
            .russian: "Папка для сохранения по умолчанию",
            .german: "Standard-Speicherort",
            .french: "Dossier d'enregistrement par défaut",
            .spanish: "Carpeta de guardado predeterminada",
            .simplifiedChinese: "默认保存目录",
            .japanese: "デフォルトの保存フォルダ"
        ],
        "settings.save_dir.not_selected": [
            .english: "Not selected",
            .russian: "Не выбрана",
            .german: "Nicht ausgewählt",
            .french: "Non sélectionné",
            .spanish: "No seleccionado",
            .simplifiedChinese: "未选择",
            .japanese: "未選択"
        ],
        "settings.choose": [
            .english: "Choose…",
            .russian: "Выбрать…",
            .german: "Auswählen…",
            .french: "Choisir…",
            .spanish: "Elegir…",
            .simplifiedChinese: "选择…",
            .japanese: "選択…"
        ],
        "settings.select_button": [
            .english: "Select",
            .russian: "Выбрать",
            .german: "Auswählen",
            .french: "Sélectionner",
            .spanish: "Seleccionar",
            .simplifiedChinese: "选择",
            .japanese: "選択"
        ],

        // Hotkeys Tab
        "settings.hotkeys.title": [
            .english: "Global Keyboard Shortcuts",
            .russian: "Глобальные сочетания клавиш",
            .german: "Globale Tastenkombinationen",
            .french: "Raccourcis clavier globaux",
            .spanish: "Atajos de teclado globales",
            .simplifiedChinese: "全局快捷键",
            .japanese: "グローバルキーボードショートカット"
        ],
        "settings.hotkeys.subtitle": [
            .english: "Assign primary and secondary shortcuts or single function keys F1–F12.",
            .russian: "Назначайте основные и альтернативные (вторые) сочетания или одиночные функциональные клавиши F1-F12.",
            .german: "Primäre und sekundäre Kürzel oder Funktionstasten F1–F12 festlegen.",
            .french: "Assignez des raccourcis principaux et secondaires ou les touches F1 à F12.",
            .spanish: "Asigne atajos principales y secundarios o teclas de función F1–F12.",
            .simplifiedChinese: "设置主要和备用快捷键，支持单个功能键 F1–F12。",
            .japanese: "主および副ショートカット、または単独のファンクションキーF1〜F12を設定します。"
        ],
        "settings.hotkeys.reset_all": [
            .english: "Reset All",
            .russian: "Сбросить все",
            .german: "Alle zurücksetzen",
            .french: "Tout réinitialiser",
            .spanish: "Restablecer todo",
            .simplifiedChinese: "重置全部",
            .japanese: "すべてリセット"
        ],
        "settings.hotkeys.area_title": [
            .english: "Area Screenshot",
            .russian: "Снимок произвольной области",
            .german: "Bereichs-Screenshot",
            .french: "Capture de zone",
            .spanish: "Captura de área",
            .simplifiedChinese: "自定义区域截图",
            .japanese: "範囲指定スクリーンショット"
        ],
        "settings.hotkeys.area_sub": [
            .english: "Select any portion of the screen with a frame",
            .russian: "Выделение рамкой любого фрагмента экрана",
            .german: "Beliebigen Bildschirmausschnitt auswählen",
            .french: "Sélectionnez n'importe quelle partie de l'écran",
            .spanish: "Seleccione cualquier parte de la pantalla",
            .simplifiedChinese: "框选屏幕任意区域进行捕获",
            .japanese: "画面上の任意の領域をドラッグしてキャプチャ"
        ],
        "settings.hotkeys.window_title": [
            .english: "Window Screenshot",
            .russian: "Снимок окна приложения",
            .german: "Fenster-Screenshot",
            .french: "Capture de fenêtre",
            .spanish: "Captura de ventana",
            .simplifiedChinese: "窗口截图",
            .japanese: "ウィンドウのスクリーンショット"
        ],
        "settings.hotkeys.window_sub": [
            .english: "Interactive click-to-capture on any open window",
            .russian: "Интерактивный выбор открытого окна кликом",
            .german: "Interaktive Fensterauswahl per Klick",
            .french: "Sélectionnez une fenêtre ouverte d'un simple clic",
            .spanish: "Selección interactiva de ventana con un clic",
            .simplifiedChinese: "点击任意打开的窗口进行交互式截图",
            .japanese: "開いているウィンドウをクリックして素早くキャプチャ"
        ],
        "settings.hotkeys.record_title": [
            .english: "Record Screen to Video",
            .russian: "Запись экрана в видео",
            .german: "Bildschirmaufnahme als Video",
            .french: "Enregistrement vidéo de l'écran",
            .spanish: "Grabar pantalla en vídeo",
            .simplifiedChinese: "屏幕录屏",
            .japanese: "画面の動画録画"
        ],
        "settings.hotkeys.record_sub": [
            .english: "Capture selected region to MP4 with floating controls",
            .russian: "Захват выбранной области в MP4 с плавающим пультом",
            .german: "Aufnahme des Bereichs als MP4 mit schwebender Leiste",
            .french: "Capture de zone en MP4 avec barre flottante",
            .spanish: "Grabar área seleccionada en MP4 con barra flotante",
            .simplifiedChinese: "录制选定区域为 MP4 视频，附带悬浮控制条",
            .japanese: "選択範囲をMP4録画し、フローティングバーで操作"
        ],
        "settings.hotkeys.repeat_title": [
            .english: "Repeat Last Capture",
            .russian: "Повторить предыдущий захват",
            .german: "Letzte Aufnahme wiederholen",
            .french: "Répéter la dernière capture",
            .spanish: "Repetir última captura",
            .simplifiedChinese: "重复上次捕获",
            .japanese: "前回のキャプチャを繰り返す"
        ],
        "settings.hotkeys.repeat_sub": [
            .english: "Instant capture of the exact same screen area",
            .russian: "Мгновенный снимок той же самой области экрана",
            .german: "Sofortige Aufnahme desselben Bereichs",
            .french: "Capture instantanée de la même zone",
            .spanish: "Captura instantánea de la misma área",
            .simplifiedChinese: "立即重新捕获相同的屏幕区域",
            .japanese: "直前と同じ画面領域を即座に再キャプチャ"
        ],
        "settings.hotkeys.history_title": [
            .english: "Capture History",
            .russian: "История снимков",
            .german: "Aufnahmeverlauf",
            .french: "Historique des captures",
            .spanish: "Historial de capturas",
            .simplifiedChinese: "截图历史",
            .japanese: "キャプチャ履歴"
        ],
        "settings.hotkeys.history_sub": [
            .english: "Gallery of all previously captured screenshots",
            .russian: "Галерея всех ранее сделанных скриншотов",
            .german: "Galerie aller zuvor erstellten Screenshots",
            .french: "Galerie de toutes les captures précédentes",
            .spanish: "Galería de capturas anteriores",
            .simplifiedChinese: "查看所有历史截图画廊",
            .japanese: "以前に撮影したすべてのスクリーンショット一覧"
        ],
        "settings.hotkeys.protected_note": [
            .english: "System shortcuts (⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space) are protected from accidental reassignment.",
            .russian: "Системные сочетания (⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space) защищены от случайного переназначения.",
            .german: "Systemkürzel (⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space) sind vor Überschreiben geschützt.",
            .french: "Les raccourcis système (⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space) sont protégés.",
            .spanish: "Los atajos del sistema (⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space) están protegidos.",
            .simplifiedChinese: "系统保留快捷键（⌘Q、⌘W、⌘H、⌘Tab、⌘Space）受保护防止误改。",
            .japanese: "システム予約ショートカット（⌘Q, ⌘W, ⌘H, ⌘Tab, ⌘Space）は保護されています。"
        ],
        "settings.hotkeys.primary": [
            .english: "Primary",
            .russian: "Основной",
            .german: "Primär",
            .french: "Principal",
            .spanish: "Principal",
            .simplifiedChinese: "主要",
            .japanese: "主"
        ],
        "settings.hotkeys.secondary": [
            .english: "Alternate",
            .russian: "Второй",
            .german: "Sekundär",
            .french: "Secondaire",
            .spanish: "Secundario",
            .simplifiedChinese: "备用",
            .japanese: "副"
        ],
        "settings.hotkeys.press_keys": [
            .english: "Press shortcut…",
            .russian: "Нажмите клавиши…",
            .german: "Tasten drücken…",
            .french: "Appuyez sur les touches…",
            .spanish: "Pulse las teclas…",
            .simplifiedChinese: "按下按键…",
            .japanese: "キーを入力…"
        ],
        "settings.hotkeys.click_to_change": [
            .english: "Click to change shortcut",
            .russian: "Кликните для изменения сочетания клавиш",
            .german: "Klicken zum Ändern",
            .french: "Cliquer pour modifier le raccourci",
            .spanish: "Haga clic para cambiar atajo",
            .simplifiedChinese: "点击修改快捷键",
            .japanese: "クリックしてショートカットを変更"
        ],
        "settings.hotkeys.remove_alt": [
            .english: "Remove alternate shortcut",
            .russian: "Удалить этот альтернативный шорткат",
            .german: "Sekundäres Kürzel entfernen",
            .french: "Supprimer le raccourci secondaire",
            .spanish: "Eliminar atajo secundario",
            .simplifiedChinese: "删除备用快捷键",
            .japanese: "副ショートカットを削除"
        ],

        // Recording Tab
        "settings.recording.params": [
            .english: "Video Settings",
            .russian: "Параметры видео",
            .german: "Videoeinstellungen",
            .french: "Paramètres vidéo",
            .spanish: "Parámetros de vídeo",
            .simplifiedChinese: "录屏参数",
            .japanese: "動画設定"
        ],
        "settings.recording.show_bar": [
            .english: "Show floating control bar with timer and pause/stop buttons",
            .russian: "Показывать плавающую панель со временем и кнопками паузы/стоп",
            .german: "Schwebende Steuerleiste mit Timer und Pause/Stopp-Tasten anzeigen",
            .french: "Afficher la barre flottante avec le chronomètre et les boutons pause/arrêt",
            .spanish: "Mostrar barra flotante con temporizador y controles",
            .simplifiedChinese: "录制时显示带有计时器与暂停/停止按钮的悬浮控制条",
            .japanese: "タイマーと一時停止/停止ボタン付きフローティングバーを表示"
        ],
        "settings.recording.show_bar_desc": [
            .english: "When enabled, a sleek control pill floats below the active recording area.",
            .russian: "Когда флажок включен, внизу записываемой области отображается стильный пульт управления.",
            .german: "Wenn aktiviert, wird eine Leiste unter dem Aufnahmebereich angezeigt.",
            .french: "Si activé, une élégante barre de contrôle s'affiche sous la zone d'enregistrement.",
            .spanish: "Muestra una barra de control elegante bajo la zona de grabación.",
            .simplifiedChinese: "开启后，录制区域下方将显示便捷的半透明控制面板。",
            .japanese: "有効にすると、録画領域の下部にコントロールバーが表示されます。"
        ],
        "settings.recording.show_keystrokes": [
            .english: "Display keystrokes and shortcuts overlay (Keystrokes HUD)",
            .russian: "Отображать нажатия клавиш и сочетания (Keystrokes HUD)",
            .german: "Tastendrücke und Shortcuts einblenden (Keystrokes HUD)",
            .french: "Afficher les frappes de touches et raccourcis (HUD)",
            .spanish: "Mostrar pulsaciones de teclas y atajos en pantalla (HUD)",
            .simplifiedChinese: "实时显示按键与快捷键提示（Keystrokes HUD）",
            .japanese: "キーストロークとショートカットを表示（HUD）"
        ],
        "settings.recording.show_keystrokes_desc": [
            .english: "Renders animated key badges (⌘, ⌥, ⇧ and letters) inside the recording bounds.",
            .russian: "Показывает всплывающие бейджи с нажимаемыми шорткатами (⌘, ⌥, ⇧ и буквы) внутри рамки записи.",
            .german: "Blendet animierte Tastenbadges innerhalb des Aufnahmebereichs ein.",
            .french: "Affiche des badges animés pour les touches pressées à l'écran.",
            .spanish: "Muestra etiquetas animadas con las teclas presionadas.",
            .simplifiedChinese: "在录屏画面中弹出平滑的按键气泡徽章（⌘、⌥、⇧ 及字符）。",
            .japanese: "録画枠内に押されたキーのバッジ（⌘, ⌥, ⇧ 等）をアニメーション表示。"
        ],
        "settings.recording.format_header": [
            .english: "Format & Codec",
            .russian: "Формат и кодек",
            .german: "Format & Codec",
            .french: "Format et codec",
            .spanish: "Formato y códec",
            .simplifiedChinese: "格式与编解码器",
            .japanese: "フォーマットとコーデック"
        ],
        "settings.recording.codec_label": [
            .english: "Recording Codec:",
            .russian: "Кодек записи:",
            .german: "Aufnahme-Codec:",
            .french: "Codec d'enregistrement :",
            .spanish: "Códec de grabación:",
            .simplifiedChinese: "录制编码：",
            .japanese: "録画コーデック:"
        ],
        "settings.recording.cursor_label": [
            .english: "Mouse Cursor Capture:",
            .russian: "Захват курсора мыши:",
            .german: "Mauszeiger erfassen:",
            .french: "Capture du curseur :",
            .spanish: "Captura de cursor:",
            .simplifiedChinese: "鼠标光标捕获：",
            .japanese: "カーソルのキャプチャ:"
        ],
        "settings.recording.cursor_enabled": [
            .english: "Enabled",
            .russian: "Включен",
            .german: "Aktiviert",
            .french: "Activé",
            .spanish: "Activado",
            .simplifiedChinese: "已启用",
            .japanese: "有効"
        ],
        "settings.recording.editor_label": [
            .english: "Video Editor Window:",
            .russian: "Окно редактирования:",
            .german: "Editor-Fenster:",
            .french: "Fenêtre d'édition :",
            .spanish: "Ventana de edición:",
            .simplifiedChinese: "视频编辑器：",
            .japanese: "編集ウィンドウ:"
        ],
        "settings.recording.editor_open": [
            .english: "Open immediately after capture",
            .russian: "Открывать сразу после записи",
            .german: "Sofort nach der Aufnahme öffnen",
            .french: "Ouvrir immédiatement après l'enregistrement",
            .spanish: "Abrir inmediatamente tras grabar",
            .simplifiedChinese: "录屏完成后立即打开",
            .japanese: "録画完了直後に開く"
        ],

        // MARK: - Annotation Editor
        "editor.title": [
            .english: "Editor — %ld × %ld",
            .russian: "Редактор — %ld × %ld",
            .german: "Editor — %ld × %ld",
            .french: "Éditeur — %ld × %ld",
            .spanish: "Editor — %ld × %ld",
            .simplifiedChinese: "编辑器 — %ld × %ld",
            .japanese: "エディタ — %ld × %ld"
        ],
        "editor.tool.select": [
            .english: "Select / Move",
            .russian: "Выбор / Перемещение",
            .german: "Auswählen / Bewegen",
            .french: "Sélectionner / Déplacer",
            .spanish: "Seleccionar / Mover",
            .simplifiedChinese: "选择 / 移动",
            .japanese: "選択 / 移動"
        ],
        "editor.tool.arrow": [
            .english: "Arrow",
            .russian: "Стрелка",
            .german: "Pfeil",
            .french: "Flèche",
            .spanish: "Flecha",
            .simplifiedChinese: "箭头",
            .japanese: "矢印"
        ],
        "editor.tool.rectangle": [
            .english: "Rectangle",
            .russian: "Прямоугольник",
            .german: "Rechteck",
            .french: "Rectangle",
            .spanish: "Rectángulo",
            .simplifiedChinese: "矩形",
            .japanese: "四角形"
        ],
        "editor.tool.rounded_rect": [
            .english: "Rounded Rect",
            .russian: "Скругленный",
            .german: "Abgerundet",
            .french: "Rectangle arrondi",
            .spanish: "Rectángulo redondeado",
            .simplifiedChinese: "圆角矩形",
            .japanese: "角丸四角形"
        ],
        "editor.tool.ellipse": [
            .english: "Oval",
            .russian: "Овал",
            .german: "Oval",
            .french: "Ovale",
            .spanish: "Óvalo",
            .simplifiedChinese: "椭圆",
            .japanese: "楕円"
        ],
        "editor.tool.text": [
            .english: "Text",
            .russian: "Текст",
            .german: "Text",
            .french: "Texte",
            .spanish: "Texto",
            .simplifiedChinese: "文本",
            .japanese: "テキスト"
        ],
        "editor.tool.counter": [
            .english: "Step Counter (1-2-3)",
            .russian: "Счетчик (1-2-3)",
            .german: "Zähler (1-2-3)",
            .french: "Compteur d'étapes (1-2-3)",
            .spanish: "Contador de pasos (1-2-3)",
            .simplifiedChinese: "序号标注 (1-2-3)",
            .japanese: "ステップ番号 (1-2-3)"
        ],
        "editor.tool.blur": [
            .english: "Blur / Redact",
            .russian: "Размытие",
            .german: "Weichzeichnen",
            .french: "Flou / Masquage",
            .spanish: "Desenfoque",
            .simplifiedChinese: "模糊 / 马赛克",
            .japanese: "モザイク / ぼかし"
        ],
        "editor.tool.highlighter": [
            .english: "Highlighter",
            .russian: "Маркер",
            .german: "Textmarker",
            .french: "Surligneur",
            .spanish: "Resaltador",
            .simplifiedChinese: "荧光高亮笔",
            .japanese: "蛍光ペン"
        ],
        "editor.tool.magnifier": [
            .english: "Magnifier",
            .russian: "Лупа",
            .german: "Lupe",
            .french: "Loupe",
            .spanish: "Lupa",
            .simplifiedChinese: "放大镜",
            .japanese: "拡大ルーペ"
        ],
        "editor.default_note_text": [
            .english: "Note text",
            .russian: "Текст заметки",
            .german: "Notiztext",
            .french: "Texte de note",
            .spanish: "Texto de nota",
            .simplifiedChinese: "注释文本",
            .japanese: "メモテキスト"
        ],
        "editor.color": [
            .english: "Color",
            .russian: "Цвет",
            .german: "Farbe",
            .french: "Couleur",
            .spanish: "Color",
            .simplifiedChinese: "颜色",
            .japanese: "色"
        ],
        "editor.choose_color": [
            .english: "Choose color",
            .russian: "Выбрать цвет",
            .german: "Farbe wählen",
            .french: "Choisir la couleur",
            .spanish: "Elegir color",
            .simplifiedChinese: "选择颜色",
            .japanese: "カラーを選択"
        ],
        "editor.line_width": [
            .english: "Line width",
            .russian: "Толщина линии",
            .german: "Linienstärke",
            .french: "Épaisseur de ligne",
            .spanish: "Grosor de línea",
            .simplifiedChinese: "线条粗细",
            .japanese: "線の太さ"
        ],
        "editor.zoom_out": [
            .english: "Zoom Out",
            .russian: "Уменьшить",
            .german: "Verkleinern",
            .french: "Zoom arrière",
            .spanish: "Alejar",
            .simplifiedChinese: "缩小",
            .japanese: "縮小"
        ],
        "editor.zoom_in": [
            .english: "Zoom In",
            .russian: "Увеличить",
            .german: "Vergrößern",
            .french: "Zoom avant",
            .spanish: "Acercar",
            .simplifiedChinese: "放大",
            .japanese: "拡大"
        ],
        "editor.fit_window": [
            .english: "Fit to Window (Auto)",
            .russian: "Вписать в окно (авто)",
            .german: "An Fenster anpassen (Auto)",
            .french: "Adapter à la fenêtre (Auto)",
            .spanish: "Ajustar a ventana (Auto)",
            .simplifiedChinese: "自适应窗口大小",
            .japanese: "ウィンドウに合わせる"
        ],
        "editor.actual_size": [
            .english: "100% (1:1)",
            .russian: "100% (1:1)",
            .german: "100% (1:1)",
            .french: "100% (1:1)",
            .spanish: "100% (1:1)",
            .simplifiedChinese: "100% (1:1)",
            .japanese: "100% (1:1)"
        ],
        "editor.auto_redact": [
            .english: "Auto-redact data (emails, credit cards, tokens)",
            .russian: "Авто-скрытие данных (email, карты, токены)",
            .german: "Daten automatisch unkenntlich machen (E-Mail, Karten, Token)",
            .french: "Masquage auto des données sensibles (emails, cartes, tokens)",
            .spanish: "Ocultación automática de datos (correos, tarjetas, tokens)",
            .simplifiedChinese: "智能脱敏敏感数据（邮箱、卡号、密钥）",
            .japanese: "個人情報の自動マスキング（メール、カード、トークン）"
        ],
        "editor.undo": [
            .english: "Undo (⌘Z)",
            .russian: "Отменить (⌘Z)",
            .german: "Widerrufen (⌘Z)",
            .french: "Annuler (⌘Z)",
            .spanish: "Deshacer (⌘Z)",
            .simplifiedChinese: "撤销 (⌘Z)",
            .japanese: "取り消す (⌘Z)"
        ],
        "editor.redo": [
            .english: "Redo (⇧⌘Z)",
            .russian: "Повторить (⇧⌘Z)",
            .german: "Wiederholen (⇧⌘Z)",
            .french: "Rétablir (⇧⌘Z)",
            .spanish: "Rehacer (⇧⌘Z)",
            .simplifiedChinese: "重做 (⇧⌘Z)",
            .japanese: "やり直す (⇧⌘Z)"
        ],
        "editor.close": [
            .english: "Close",
            .russian: "Закрыть",
            .german: "Schließen",
            .french: "Fermer",
            .spanish: "Cerrar",
            .simplifiedChinese: "关闭",
            .japanese: "閉じる"
        ],
        "editor.copy": [
            .english: "Copy",
            .russian: "Копировать",
            .german: "Kopieren",
            .french: "Copier",
            .spanish: "Copiar",
            .simplifiedChinese: "复制",
            .japanese: "コピー"
        ],
        "editor.save": [
            .english: "Save",
            .russian: "Сохранить",
            .german: "Speichern",
            .french: "Enregistrer",
            .spanish: "Guardar",
            .simplifiedChinese: "保存",
            .japanese: "保存"
        ],
        "editor.saved": [
            .english: "Saved ✓",
            .russian: "Сохранено ✓",
            .german: "Gespeichert ✓",
            .french: "Enregistré ✓",
            .spanish: "Guardado ✓",
            .simplifiedChinese: "已保存 ✓",
            .japanese: "保存済み ✓"
        ],
        "editor.save_history_help": [
            .english: "Save annotated image to app history (⌘S)",
            .russian: "Сохранить снимок с аннотациями в историю приложения (⌘S)",
            .german: "Bild mit Anmerkungen im Verlauf speichern (⌘S)",
            .french: "Enregistrer l'image annotée dans l'historique (⌘S)",
            .spanish: "Guardar imagen con anotaciones en el historial (⌘S)",
            .simplifiedChinese: "将带标注的截图保存至应用历史 (⌘S)",
            .japanese: "注釈付き画像をアプリ履歴に保存 (⌘S)"
        ],
        "editor.export": [
            .english: "Export…",
            .russian: "Экспорт…",
            .german: "Exportieren…",
            .french: "Exporter…",
            .spanish: "Exportar…",
            .simplifiedChinese: "导出…",
            .japanese: "エクスポート…"
        ],
        "editor.export_help": [
            .english: "Export to file via save panel (⌘E)",
            .russian: "Экспортировать в файл через диалог сохранения (⌘E)",
            .german: "Über Speichern-Dialog exportieren (⌘E)",
            .french: "Exporter le fichier via le dialogue de sauvegarde (⌘E)",
            .spanish: "Exportar a archivo mediante diálogo (⌘E)",
            .simplifiedChinese: "通过保存对话框导出到文件 (⌘E)",
            .japanese: "ファイル保存ダイアログからエクスポート (⌘E)"
        ],
        "editor.backdrop": [
            .english: "Backdrop",
            .russian: "Фон",
            .german: "Hintergrund",
            .french: "Fond",
            .spanish: "Fondo",
            .simplifiedChinese: "背景美化",
            .japanese: "背景"
        ],
        "editor.gradient_presets": [
            .english: "Gradient Presets",
            .russian: "Градиентные пресеты",
            .german: "Verlaufsvorlagen",
            .french: "Préréglages dégradés",
            .spanish: "Ajustes de degradado",
            .simplifiedChinese: "渐变预设",
            .japanese: "グラデーションプリセット"
        ],
        "editor.padding": [
            .english: "Padding",
            .russian: "Отступ",
            .german: "Abstand",
            .french: "Marge",
            .spanish: "Margen",
            .simplifiedChinese: "边距",
            .japanese: "余白"
        ],
        "editor.corners": [
            .english: "Corners",
            .russian: "Углы",
            .german: "Ecken",
            .french: "Coins",
            .spanish: "Esquinas",
            .simplifiedChinese: "圆角",
            .japanese: "角丸"
        ],
        "editor.shadow": [
            .english: "Shadow",
            .russian: "Тень",
            .german: "Schatten",
            .french: "Ombre",
            .spanish: "Sombra",
            .simplifiedChinese: "阴影",
            .japanese: "シャドウ"
        ],
        "editor.shadow_help": [
            .english: "Toggle soft screenshot shadow",
            .russian: "Включить мягкую тень скриншота",
            .german: "Weichen Schatten aktivieren",
            .french: "Activer une ombre douce",
            .spanish: "Activar sombra suave",
            .simplifiedChinese: "开启柔和投影效果",
            .japanese: "ソフトシャドウの切り替え"
        ],
        "editor.unit_px": [
            .english: "px",
            .russian: "пкс",
            .german: "px",
            .french: "px",
            .spanish: "px",
            .simplifiedChinese: "像素",
            .japanese: "px"
        ],

        // Selected Item Bar
        "editor.selected.text_field": [
            .english: "Text",
            .russian: "Текст",
            .german: "Text",
            .french: "Texte",
            .spanish: "Texto",
            .simplifiedChinese: "文本",
            .japanese: "テキスト"
        ],
        "editor.selected.font_smaller": [
            .english: "Smaller Font",
            .russian: "Меньше шрифт",
            .german: "Schrift kleiner",
            .french: "Police plus petite",
            .spanish: "Fuente más pequeña",
            .simplifiedChinese: "减小字号",
            .japanese: "フォント縮小"
        ],
        "editor.selected.font_larger": [
            .english: "Larger Font",
            .russian: "Больше шрифт",
            .german: "Schrift größer",
            .french: "Police plus grande",
            .spanish: "Fuente más grande",
            .simplifiedChinese: "增大字号",
            .japanese: "フォント拡大"
        ],
        "editor.selected.num_minus": [
            .english: "Number −1",
            .russian: "Номер −1",
            .german: "Nummer −1",
            .french: "Numéro −1",
            .spanish: "Número −1",
            .simplifiedChinese: "序号 −1",
            .japanese: "番号 −1"
        ],
        "editor.selected.num_plus": [
            .english: "Number +1",
            .russian: "Номер +1",
            .german: "Nummer +1",
            .french: "Numéro +1",
            .spanish: "Número +1",
            .simplifiedChinese: "序号 +1",
            .japanese: "番号 +1"
        ],
        "editor.selected.rotate_left": [
            .english: "Rotate −15°",
            .russian: "Повернуть −15°",
            .german: "Drehen −15°",
            .french: "Pivoter −15°",
            .spanish: "Girar −15°",
            .simplifiedChinese: "逆时针旋转 15°",
            .japanese: "回転 −15°"
        ],
        "editor.selected.rotate_right": [
            .english: "Rotate +15°",
            .russian: "Повернуть +15°",
            .german: "Drehen +15°",
            .french: "Pivoter +15°",
            .spanish: "Girar +15°",
            .simplifiedChinese: "顺时针旋转 15°",
            .japanese: "回転 +15°"
        ],
        "editor.selected.reset_angle": [
            .english: "Reset Angle",
            .russian: "Сбросить угол",
            .german: "Winkel zurücksetzen",
            .french: "Réinitialiser l'angle",
            .spanish: "Restablecer ángulo",
            .simplifiedChinese: "重置角度",
            .japanese: "角度をリセット"
        ],
        "editor.selected.duplicate": [
            .english: "Duplicate (⌘D)",
            .russian: "Дублировать (⌘D)",
            .german: "Duplizieren (⌘D)",
            .french: "Dupliquer (⌘D)",
            .spanish: "Duplicar (⌘D)",
            .simplifiedChinese: "复制副本 (⌘D)",
            .japanese: "複製 (⌘D)"
        ],
        "editor.selected.delete": [
            .english: "Delete (⌘⌫)",
            .russian: "Удалить (⌘⌫)",
            .german: "Löschen (⌘⌫)",
            .french: "Supprimer (⌘⌫)",
            .spanish: "Eliminar (⌘⌫)",
            .simplifiedChinese: "删除 (⌘⌫)",
            .japanese: "削除 (⌘⌫)"
        ],
        "editor.selected.deselect": [
            .english: "Deselect (Esc)",
            .russian: "Снять выделение (Esc)",
            .german: "Abwählen (Esc)",
            .french: "Désélectionner (Esc)",
            .spanish: "Deseleccionar (Esc)",
            .simplifiedChinese: "取消选中 (Esc)",
            .japanese: "選択解除 (Esc)"
        ],
        "editor.selected.empty_hint": [
            .english: "Select an element on canvas to modify properties (rotation, size, color, delete)",
            .russian: "Выберите элемент на холсте для редактирования свойств (поворот, размер, цвет, удаление)",
            .german: "Element auswählen, um Eigenschaften anzupassen (Drehung, Größe, Farbe, Löschen)",
            .french: "Sélectionnez un élément sur la zone pour modifier ses propriétés (rotation, taille, couleur, suppression)",
            .spanish: "Seleccione un elemento para cambiar sus propiedades (rotación, tamaño, color, eliminar)",
            .simplifiedChinese: "在画布上选择元素以调整属性（旋转、大小、颜色、删除）",
            .japanese: "キャンバス上の要素を選択してプロパティ（回転、サイズ、色、削除）を編集"
        ],
        "editor.selected.shortcuts_hint": [
            .english: "⌘Z undo • ⌘D duplicate • ⌫ delete",
            .russian: "⌘Z отмена • ⌘D дублировать • ⌫ удалить",
            .german: "⌘Z widerrufen • ⌘D duplizieren • ⌫ löschen",
            .french: "⌘Z annuler • ⌘D dupliquer • ⌫ supprimer",
            .spanish: "⌘Z deshacer • ⌘D duplicar • ⌫ eliminar",
            .simplifiedChinese: "⌘Z 撤销 • ⌘D 复制 • ⌫ 删除",
            .japanese: "⌘Z 取り消し • ⌘D 複製 • ⌫ 削除"
        ],

        // Backdrop Presets
        "preset.aurora": [
            .english: "Aurora",
            .russian: "Аврора",
            .german: "Aurora",
            .french: "Aurore",
            .spanish: "Aurora",
            .simplifiedChinese: "极光",
            .japanese: "オーロラ"
        ],
        "preset.ocean": [
            .english: "Ocean",
            .russian: "Океан",
            .german: "Ozean",
            .french: "Océan",
            .spanish: "Océano",
            .simplifiedChinese: "深海",
            .japanese: "オーシャン"
        ],
        "preset.sunset": [
            .english: "Sunset",
            .russian: "Закат",
            .german: "Sonnenuntergang",
            .french: "Coucher de soleil",
            .spanish: "Atardecer",
            .simplifiedChinese: "落日",
            .japanese: "夕焼け"
        ],
        "preset.forest": [
            .english: "Forest",
            .russian: "Лес",
            .german: "Wald",
            .french: "Forêt",
            .spanish: "Bosque",
            .simplifiedChinese: "森林",
            .japanese: "フォレスト"
        ],
        "preset.graphite": [
            .english: "Graphite",
            .russian: "Графит",
            .german: "Graphit",
            .french: "Graphite",
            .spanish: "Grafito",
            .simplifiedChinese: "石墨",
            .japanese: "グラファイト"
        ],
        "preset.snow": [
            .english: "Snow",
            .russian: "Снег",
            .german: "Schnee",
            .french: "Neige",
            .spanish: "Nieve",
            .simplifiedChinese: "纯雪",
            .japanese: "スノー"
        ],

        // Dialogs & Alerts
        "alert.unsaved_title": [
            .english: "Save changes to history before closing?",
            .russian: "Сохранить изменения в историю перед закрытием?",
            .german: "Änderungen vor dem Schließen im Verlauf speichern?",
            .french: "Enregistrer les modifications dans l'historique avant de fermer ?",
            .spanish: "¿Guardar cambios en el historial antes de cerrar?",
            .simplifiedChinese: "关闭前是否将更改保存至历史记录？",
            .japanese: "閉じる前に変更を履歴に保存しますか？"
        ],
        "alert.unsaved_informative": [
            .english: "The editor contains unsaved annotations or styling modifications.",
            .russian: "В редакторе есть несохранённые аннотации или изменения оформления.",
            .german: "Der Editor enthält nicht gespeicherte Anmerkungen oder Stile.",
            .french: "L'éditeur contient des annotations ou styles non enregistrés.",
            .spanish: "El editor contiene anotaciones o estilos no guardados.",
            .simplifiedChinese: "编辑器中包含未保存的标注或背景修改。",
            .japanese: "エディタに保存されていない注釈や変更があります。"
        ],
        "alert.save": [
            .english: "Save",
            .russian: "Сохранить",
            .german: "Speichern",
            .french: "Enregistrer",
            .spanish: "Guardar",
            .simplifiedChinese: "保存",
            .japanese: "保存"
        ],
        "alert.dont_save": [
            .english: "Don't Save",
            .russian: "Не сохранять",
            .german: "Nicht speichern",
            .french: "Ne pas enregistrer",
            .spanish: "No guardar",
            .simplifiedChinese: "不保存",
            .japanese: "保存しない"
        ],
        "alert.cancel": [
            .english: "Cancel",
            .russian: "Отмена",
            .german: "Abbrechen",
            .french: "Annuler",
            .spanish: "Cancelar",
            .simplifiedChinese: "取消",
            .japanese: "キャンセル"
        ],
        "alert.permission_title": [
            .english: "Screen Recording Access Required",
            .russian: "Требуется доступ к записи экрана",
            .german: "Bildschirmaufnahme-Berechtigung erforderlich",
            .french: "Accès à l'enregistrement d'écran requis",
            .spanish: "Se requiere acceso de grabación de pantalla",
            .simplifiedChinese: "需要屏幕录制权限",
            .japanese: "画面録画のアクセス権が必要です"
        ],
        "alert.permission_informative": [
            .english: "Just Screenshot requires Screen & System Audio Recording permission in macOS System Settings to capture screenshots and record video.\n\nPlease grant access and restart the app if necessary.",
            .russian: "Для создания снимков и записи экрана приложению Just Screenshot требуется разрешение «Запись экрана и аудиосистемы» в Настройках macOS.\n\nПожалуйста, включите доступ и перезапустите приложение при необходимости.",
            .german: "Just Screenshot benötigt die Berechtigung zur Bildschirm- und Systemtonaufnahme in den macOS-Einstellungen.\n\nBitte Berechtigung erteilen und die App bei Bedarf neu starten.",
            .french: "Just Screenshot requiert l'autorisation d'enregistrement de l'écran et de l'audio dans les Réglages Système de macOS.\n\nVeuillez accorder l'accès et redémarrer l'application si nécessaire.",
            .spanish: "Just Screenshot necesita permiso de Grabación de pantalla y audio del sistema en Ajustes de macOS.\n\nConceda acceso y reinicie la app si es necesario.",
            .simplifiedChinese: "Just Screenshot 需要在 macOS 系统设置中开启「屏幕与系统音频录制」权限，以便截取屏幕和录制视频。\n\n请授予权限并在需要时重启应用。",
            .japanese: "Just Screenshot でスクリーンショットや録画を行うには、macOSの「画面とシステムオーディオの録音」権限が必要です。\n\nアクセス権を許可し、必要に応じてアプリを再起動してください。"
        ],
        "alert.open_settings": [
            .english: "Open Settings",
            .russian: "Открыть Настройки",
            .german: "Einstellungen öffnen",
            .french: "Ouvrir les Réglages",
            .spanish: "Abrir Ajustes",
            .simplifiedChinese: "打开设置",
            .japanese: "設定を開く"
        ],

        // MARK: - History Window
        "history.title": [
            .english: "Capture History",
            .russian: "История снимков",
            .german: "Aufnahmeverlauf",
            .french: "Historique des captures",
            .spanish: "Historial de capturas",
            .simplifiedChinese: "截图历史",
            .japanese: "キャプチャ履歴"
        ],
        "history.clear_all": [
            .english: "Clear All",
            .russian: "Очистить всё",
            .german: "Alles löschen",
            .french: "Tout effacer",
            .spanish: "Borrar todo",
            .simplifiedChinese: "清空全部",
            .japanese: "すべて消去"
        ],
        "history.empty_title": [
            .english: "No Captures Yet",
            .russian: "Пока нет снимков",
            .german: "Noch keine Aufnahmen",
            .french: "Aucune capture pour le moment",
            .spanish: "Aún no hay capturas",
            .simplifiedChinese: "暂无截图",
            .japanese: "キャプチャはまだありません"
        ],
        "history.empty_subtitle": [
            .english: "Take a screenshot (⌘⇧4 / ⌘⇧5) — it will appear here",
            .russian: "Сделайте скриншот (⌘⇧4 / ⌘⇧5) — он появится здесь",
            .german: "Erstellen Sie einen Screenshot (⌘⇧4 / ⌘⇧5) — er wird hier angezeigt",
            .french: "Prenez une capture (⌘⇧4 / ⌘⇧5) — elle apparaîtra ici",
            .spanish: "Haga una captura (⌘⇧4 / ⌘⇧5) — aparecerá aquí",
            .simplifiedChinese: "截取屏幕 (⌘⇧4 / ⌘⇧5) — 将自动显示在此处",
            .japanese: "スクリーンショット (⌘⇧4 / ⌘⇧5) を撮影すると、ここに表示されます"
        ],
        "history.clear_confirm_title": [
            .english: "Delete entire history?",
            .russian: "Удалить всю историю?",
            .german: "Gesamten Verlauf löschen?",
            .french: "Supprimer tout l'historique ?",
            .spanish: "¿Eliminar todo el historial?",
            .simplifiedChinese: "清空所有历史截图？",
            .japanese: "すべての履歴を削除しますか？"
        ],
        "history.delete_button": [
            .english: "Delete",
            .russian: "Удалить",
            .german: "Löschen",
            .french: "Supprimer",
            .spanish: "Eliminar",
            .simplifiedChinese: "删除",
            .japanese: "削除"
        ],
        "history.edit": [
            .english: "Edit",
            .russian: "Редактировать",
            .german: "Bearbeiten",
            .french: "Modifier",
            .spanish: "Editar",
            .simplifiedChinese: "编辑",
            .japanese: "編集"
        ],
        "history.pin": [
            .english: "Pin to Screen",
            .russian: "Закрепить на экране",
            .german: "Am Bildschirm anheften",
            .french: "Épingler à l'écran",
            .spanish: "Fijar en pantalla",
            .simplifiedChinese: "固定到屏幕",
            .japanese: "画面に固定"
        ],
        "history.reveal_finder": [
            .english: "Show in Finder",
            .russian: "Показать в Finder",
            .german: "Im Finder zeigen",
            .french: "Afficher dans le Finder",
            .spanish: "Mostrar en Finder",
            .simplifiedChinese: "在访达中显示",
            .japanese: "Finder で表示"
        ],

        // MARK: - HUD & Quick Access
        "hud.screenshot": [
            .english: "Screenshot",
            .russian: "Снимок экрана",
            .german: "Bildschirmfoto",
            .french: "Capture d'écran",
            .spanish: "Captura de pantalla",
            .simplifiedChinese: "屏幕截图",
            .japanese: "スクリーンショット"
        ],
        "hud.editor": [
            .english: "Editor",
            .russian: "Редактор",
            .german: "Editor",
            .french: "Éditeur",
            .spanish: "Editor",
            .simplifiedChinese: "编辑器",
            .japanese: "エディタ"
        ],
        "hud.save_as": [
            .english: "Save As…",
            .russian: "Сохранить как…",
            .german: "Speichern unter…",
            .french: "Enregistrer sous…",
            .spanish: "Guardar como…",
            .simplifiedChinese: "另存为…",
            .japanese: "名前を付けて保存…"
        ],
        "hud.pin_top": [
            .english: "Pin on Top of Windows",
            .russian: "Закрепить поверх окон",
            .german: "Im Vordergrund anheften",
            .french: "Épingler au premier plan",
            .spanish: "Fijar en primer plano",
            .simplifiedChinese: "置顶固定在屏幕上",
            .japanese: "最前面にピン留め"
        ],
        "hud.ocr_button": [
            .english: "Recognize & Copy Text (OCR)",
            .russian: "Распознать текст и скопировать",
            .german: "Text erkennen & kopieren (OCR)",
            .french: "Reconnaître et copier le texte (OCR)",
            .spanish: "Reconocer y copiar texto (OCR)",
            .simplifiedChinese: "文字识别并复制 (OCR)",
            .japanese: "テキストを認識してコピー (OCR)"
        ],
        "hud.copied": [
            .english: "Copied!",
            .russian: "Скопировано",
            .german: "Kopiert!",
            .french: "Copié !",
            .spanish: "¡Copiado!",
            .simplifiedChinese: "已复制！",
            .japanese: "コピーしました！"
        ],
        "hud.recognizing": [
            .english: "Recognizing…",
            .russian: "Распознаю…",
            .german: "Erkennen…",
            .french: "Reconnaissance…",
            .spanish: "Reconociendo…",
            .simplifiedChinese: "正在识别…",
            .japanese: "テキスト認識中…"
        ],
        "hud.ocr_not_found": [
            .english: "No text found",
            .russian: "Текст не найден",
            .german: "Kein Text gefunden",
            .french: "Aucun texte trouvé",
            .spanish: "No se encontró texto",
            .simplifiedChinese: "未发现文本",
            .japanese: "テキストが見つかりません"
        ],
        "hud.ocr_copied": [
            .english: "Text copied\n(%ld chars)",
            .russian: "Текст скопирован\n(%ld симв.)",
            .german: "Text kopiert\n(%ld Zeichen)",
            .french: "Texte copié\n(%ld car.)",
            .spanish: "Texto copiado\n(%ld caract.)",
            .simplifiedChinese: "文字已复制\n（%ld 字符）",
            .japanese: "テキストをコピーしました\n（%ld文字）"
        ],

        // MARK: - Overlay Prompts
        "overlay.window_tip": [
            .english: "Click a window to capture • ESC to cancel",
            .russian: "Кликните по окну для скриншота окна • ESC для отмены",
            .german: "Fenster anklicken zum Aufnehmen • ESC zum Abbrechen",
            .french: "Cliquez sur une fenêtre pour capturer • Échap pour annuler",
            .spanish: "Haga clic en una ventana para capturar • ESC para cancelar",
            .simplifiedChinese: "单击窗口进行截图 • ESC 取消",
            .japanese: "ウィンドウをクリックしてキャプチャ • ESC でキャンセル"
        ],
        "overlay.area_tip": [
            .english: "Drag to select area • ⌥ + Click copies pixel color • ESC to cancel",
            .russian: "Выделите область • ⌥ + Клик скопирует цвет пикселя • ESC для отмены",
            .german: "Bereich aufziehen • ⌥ + Klick kopiert Pixelfarbe • ESC zum Abbrechen",
            .french: "Sélectionnez une zone • ⌥ + Clic copie la couleur • Échap pour annuler",
            .spanish: "Arrastre para seleccionar área • ⌥ + Clic copia color • ESC para cancelar",
            .simplifiedChinese: "拖动选择区域 • ⌥ + 单击吸取像素颜色 • ESC 取消",
            .japanese: "ドラッグして範囲を選択 • ⌥ + クリックで色をコピー • ESC でキャンセル"
        ],
        "overlay.record_tip": [
            .english: "Select area to record video (MP4) • ESC to cancel",
            .russian: "Выделите область для записи экрана в видео (MP4) • ESC для отмены",
            .german: "Bereich für Videoaufnahme (MP4) wählen • ESC zum Abbrechen",
            .french: "Sélectionnez la zone pour enregistrer en vidéo (MP4) • Échap pour annuler",
            .spanish: "Seleccione área para grabar vídeo (MP4) • ESC para cancelar",
            .simplifiedChinese: "框选录屏区域 (MP4) • ESC 取消",
            .japanese: "動画録画（MP4）の範囲を選択 • ESC でキャンセル"
        ],
        "overlay.window_badge": [
            .english: "📸 %@ • Click to capture window",
            .russian: "📸 %@ • Кликните для снимка окна",
            .german: "📸 %@ • Klicken für Fenster-Screenshot",
            .french: "📸 %@ • Cliquer pour capturer la fenêtre",
            .spanish: "📸 %@ • Clic para capturar ventana",
            .simplifiedChinese: "📸 %@ • 单击以捕获窗口",
            .japanese: "📸 %@ • クリックしてウィンドウをキャプチャ"
        ],
        "overlay.window_fallback": [
            .english: "Window",
            .russian: "Окно",
            .german: "Fenster",
            .french: "Fenêtre",
            .spanish: "Ventana",
            .simplifiedChinese: "窗口",
            .japanese: "ウィンドウ"
        ],

        // MARK: - Pin Window
        "pin.unpin": [
            .english: "Unpin",
            .russian: "Открепить",
            .german: "Lösen",
            .french: "Détacher",
            .spanish: "Desfijar",
            .simplifiedChinese: "取消置顶",
            .japanese: "固定解除"
        ],
        "pin.opacity": [
            .english: "Opacity",
            .russian: "Прозрачность",
            .german: "Deckkraft",
            .french: "Opacité",
            .spanish: "Opacidad",
            .simplifiedChinese: "不透明度",
            .japanese: "不透明度"
        ],

        // MARK: - Live Recording Bar
        "recording.bar.pause_badge": [
            .english: "PAUSED",
            .russian: "ПАУЗА",
            .german: "PAUSE",
            .french: "EN PAUSE",
            .spanish: "PAUSA",
            .simplifiedChinese: "已暂停",
            .japanese: "一時停止"
        ],
        "recording.bar.resume_help": [
            .english: "Resume recording",
            .russian: "Возобновить запись",
            .german: "Aufnahme fortsetzen",
            .french: "Reprendre l'enregistrement",
            .spanish: "Reanudar grabación",
            .simplifiedChinese: "继续录屏",
            .japanese: "録画を再開"
        ],
        "recording.bar.pause_help": [
            .english: "Pause recording",
            .russian: "Приостановить запись",
            .german: "Aufnahme pausieren",
            .french: "Mettre en pause l'enregistrement",
            .spanish: "Pausar grabación",
            .simplifiedChinese: "暂停录屏",
            .japanese: "録画を一時停止"
        ],
        "recording.bar.done": [
            .english: "Done",
            .russian: "Готово",
            .german: "Fertig",
            .french: "Terminé",
            .spanish: "Listo",
            .simplifiedChinese: "完成",
            .japanese: "完了"
        ],
        "recording.bar.done_help": [
            .english: "Stop recording and save video",
            .russian: "Остановить запись и сохранить видео",
            .german: "Aufnahme beenden und Video speichern",
            .french: "Arrêter l'enregistrement et sauvegarder la vidéo",
            .spanish: "Detener grabación y guardar vídeo",
            .simplifiedChinese: "停止录制并保存视频",
            .japanese: "録画を停止して動画を保存"
        ],
        "recording.bar.cancel_help": [
            .english: "Discard recording without saving",
            .russian: "Отменить запись без сохранения",
            .german: "Aufnahme ohne Speichern verwerfen",
            .french: "Annuler l'enregistrement sans sauvegarder",
            .spanish: "Descartar grabación sin guardar",
            .simplifiedChinese: "丢弃录制且不保存",
            .japanese: "保存せずに録画を破棄"
        ],

        // MARK: - Video Editor
        "video_editor.title": [
            .english: "Video Editor — %@",
            .russian: "Редактор видео — %@",
            .german: "Video-Editor — %@",
            .french: "Éditeur vidéo — %@",
            .spanish: "Editor de vídeo — %@",
            .simplifiedChinese: "视频编辑器 — %@",
            .japanese: "動画エディタ — %@"
        ],
        "video_editor.back_1s": [
            .english: "Back 1 sec",
            .russian: "Назад на 1 сек",
            .german: "1 Sek zurück",
            .french: "Reculer de 1 s",
            .spanish: "Retroceder 1 s",
            .simplifiedChinese: "快退 1 秒",
            .japanese: "1秒戻る"
        ],
        "video_editor.play_pause": [
            .english: "Play / Pause (Space)",
            .russian: "Воспроизведение / Пауза (Пробел)",
            .german: "Wiedergabe / Pause (Leertaste)",
            .french: "Lecture / Pause (Espace)",
            .spanish: "Reproducir / Pausa (Espacio)",
            .simplifiedChinese: "播放 / 暂停 (空格键)",
            .japanese: "再生 / 一時停止 (スペース)"
        ],
        "video_editor.forward_1s": [
            .english: "Forward 1 sec",
            .russian: "Вперед на 1 сек",
            .german: "1 Sek vor",
            .french: "Avancer de 1 s",
            .spanish: "Avanzar 1 s",
            .simplifiedChinese: "快进 1 秒",
            .japanese: "1秒進む"
        ],
        "video_editor.duration": [
            .english: "Duration: %@ s",
            .russian: "Длительность: %@ с",
            .german: "Dauer: %@ s",
            .french: "Durée : %@ s",
            .spanish: "Duración: %@ s",
            .simplifiedChinese: "时长：%@ 秒",
            .japanese: "長さ: %@ 秒"
        ],
        "video_editor.exporting_gif": [
            .english: "Generating GIF animation...",
            .russian: "Генерация GIF анимации...",
            .german: "GIF-Animation wird erstellt...",
            .french: "Génération de l'animation GIF...",
            .spanish: "Generando animación GIF...",
            .simplifiedChinese: "正在生成 GIF 动图...",
            .japanese: "GIFアニメーションを生成中..."
        ],
        "video_editor.exporting_mp4": [
            .english: "Exporting MP4 video...",
            .russian: "Экспорт видео в MP4...",
            .german: "Exportiere Video als MP4...",
            .french: "Exportation de la vidéo en MP4...",
            .spanish: "Exportando vídeo a MP4...",
            .simplifiedChinese: "正在导出 MP4 视频...",
            .japanese: "MP4動画をエクスポート中..."
        ],
        "video_editor.export_error": [
            .english: "Export Error",
            .russian: "Ошибка экспорта",
            .german: "Exportfehler",
            .french: "Erreur d'exportation",
            .spanish: "Error de exportación",
            .simplifiedChinese: "导出错误",
            .japanese: "エクスポートエラー"
        ],
        "video_editor.add_annotation": [
            .english: "Add %@",
            .russian: "Добавить %@",
            .german: "%@ hinzufügen",
            .french: "Ajouter %@",
            .spanish: "Añadir %@",
            .simplifiedChinese: "添加 %@",
            .japanese: "%@を追加"
        ],
        "video_editor.crop": [
            .english: "Crop",
            .russian: "Кадрировать",
            .german: "Zuschneiden",
            .french: "Recadrer",
            .spanish: "Recortar",
            .simplifiedChinese: "裁剪画面",
            .japanese: "クロップ"
        ],
        "video_editor.crop_help": [
            .english: "Toggle video crop area",
            .russian: "Включить или отключить область кадрирования видео",
            .german: "Zuschneidebereich umschalten",
            .french: "Activer/désactiver la zone de recadrage",
            .spanish: "Activar/desactivar recorte de vídeo",
            .simplifiedChinese: "开启或关闭视频裁剪区域",
            .japanese: "クロップ枠の切り替え"
        ],
        "video_editor.speed_05": [
            .english: "0.5x Slow",
            .russian: "0.5x Замедленно",
            .german: "0.5x Verlangsamt",
            .french: "0.5x Ralenti",
            .spanish: "0.5x Lento",
            .simplifiedChinese: "0.5x 慢速",
            .japanese: "0.5x スロー"
        ],
        "video_editor.speed_10": [
            .english: "1.0x Normal",
            .russian: "1.0x Обычная",
            .german: "1.0x Normal",
            .french: "1.0x Normal",
            .spanish: "1.0x Normal",
            .simplifiedChinese: "1.0x 正常速度",
            .japanese: "1.0x 標準"
        ],
        "video_editor.speed_15": [
            .english: "1.5x Fast",
            .russian: "1.5x Ускорено",
            .german: "1.5x Schnell",
            .french: "1.5x Accéléré",
            .spanish: "1.5x Rápido",
            .simplifiedChinese: "1.5x 加速",
            .japanese: "1.5x 高速"
        ],
        "video_editor.speed_20": [
            .english: "2.0x Double speed",
            .russian: "2.0x В 2 раза быстрее",
            .german: "2.0x Doppelt so schnell",
            .french: "2.0x 2× plus rapide",
            .spanish: "2.0x Doble velocidad",
            .simplifiedChinese: "2.0x 双倍速度",
            .japanese: "2.0x 2倍速"
        ],
        "video_editor.export_gif": [
            .english: "GIF",
            .russian: "GIF",
            .german: "GIF",
            .french: "GIF",
            .spanish: "GIF",
            .simplifiedChinese: "GIF",
            .japanese: "GIF"
        ],
        "video_editor.export_gif_help": [
            .english: "Export selection as animated GIF",
            .russian: "Экспортировать выбранный фрагмент как анимированный GIF",
            .german: "Auswahl als animiertes GIF exportieren",
            .french: "Exporter la sélection en GIF animé",
            .spanish: "Exportar fragmento como GIF animado",
            .simplifiedChinese: "将选定片段导出为 GIF 动图",
            .japanese: "選択した区間をアニメーションGIFとして書き出す"
        ],
        "video_editor.save_mp4": [
            .english: "Save MP4",
            .russian: "Сохранить MP4",
            .german: "MP4 speichern",
            .french: "Enregistrer MP4",
            .spanish: "Guardar MP4",
            .simplifiedChinese: "保存 MP4",
            .japanese: "MP4 を保存"
        ],
        "video_editor.save_mp4_help": [
            .english: "Export trimmed video to MP4",
            .russian: "Экспортировать готовое видео в MP4",
            .german: "Fertiges Video als MP4 exportieren",
            .french: "Exporter la vidéo prête en MP4",
            .spanish: "Exportar vídeo final a MP4",
            .simplifiedChinese: "将裁剪编辑后的视频导出为 MP4",
            .japanese: "編集済み動画を MP4 に書き出す"
        ],
        "video_editor.type_text": [
            .english: "Text",
            .russian: "Текст",
            .german: "Text",
            .french: "Texte",
            .spanish: "Texto",
            .simplifiedChinese: "文本",
            .japanese: "テキスト"
        ],
        "video_editor.type_arrow": [
            .english: "Arrow",
            .russian: "Стрелка",
            .german: "Pfeil",
            .french: "Flèche",
            .spanish: "Flecha",
            .simplifiedChinese: "箭头",
            .japanese: "矢印"
        ],
        "video_editor.type_rect": [
            .english: "Frame",
            .russian: "Рамка",
            .german: "Rahmen",
            .french: "Cadre",
            .spanish: "Marco",
            .simplifiedChinese: "框选",
            .japanese: "フレーム"
        ],
        "video_editor.type_blur": [
            .english: "Blur",
            .russian: "Размытие",
            .german: "Weichzeichnen",
            .french: "Flou",
            .spanish: "Desenfoque",
            .simplifiedChinese: "模糊",
            .japanese: "ぼかし"
        ]
    ]

    public static func translate(_ key: String, for language: AppLanguage) -> String {
        guard let map = translations[key] else {
            return key
        }
        if let value = map[language] {
            return value
        }
        if let fallback = map[.english] {
            return fallback
        }
        return key
    }
}
