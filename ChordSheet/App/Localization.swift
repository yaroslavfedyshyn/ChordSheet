import Foundation

/// Every user-facing string key in the app. Values live in `L10n.tables`
/// below, one dictionary per `AppLanguage`. Keys mirror the design
/// prototype's own `T`/`S` dictionaries where a matching string exists there;
/// keys the design doesn't have (import/export, delete confirmation, pin,
/// sort option names) are original translations in the same tone.
enum LKey: String {
    case search, all, delete, noTags
    case emptyNone, emptyTag, emptyQuery, or
    case untitled, save, tagOne, addTags
    case transposeHeader, detectKey, fixKey, now
    case notEnough, notEnoughNote
    case fits, looks, couldBe, badgeSays
    case majorSuffix, minorSuffix
    case startHint, insertChord, variants
    case hideKeyboard, allChords, done
    case tagsHeader, findTag, create, sheetEmpty
    case keepChanges, unsaved, thisSong, discard, saved
    case library, importSongs, exportSongs
    case appearance, light, dark, auto
    case language, deviceAsks, deviceMissing
    case sortHeader, sortAlphabet, sortMostRecent, sortOldestFirst
    case cancel, deleteConfirmTitle, cantUndo
    case replaceLibraryTitle, replaceButton, importingWillReplace
    case importFailedTitle, ok
    case couldntPrepareExport, couldntOpenFile, couldntReadFile
    case backupCorrupt, backupUnsupportedVersion
    case unpinAll, pin, unpin
    case openQuote, closeQuote
    case accentTeal, accentMarine, accentClay, accentPlum
}

extension AppLanguage {
    var strings: L10n { L10n(language: self) }
}

/// Looks up `LKey` strings for one language, falling back to English for any
/// key a language's table happens to be missing (mirrors the design's
/// `t() { Object.assign({}, T.en, T[lang]) }` merge).
struct L10n {
    let language: AppLanguage

    subscript(_ key: LKey) -> String {
        L10n.tables[language]?[key] ?? L10n.tables[.en]?[key] ?? key.rawValue
    }

    /// Positional `%@` substitution — simpler and safer than
    /// `String(format:)` for hand-written, non-format-specifier templates.
    func format(_ key: LKey, _ args: String...) -> String {
        var result = self[key]
        for arg in args {
            guard let range = result.range(of: "%@") else { break }
            result.replaceSubrange(range, with: arg)
        }
        return result
    }

    /// A song's display name for messages like "“Slow River” has unsaved
    /// edits." / "Delete “Slow River”?" — falls back to `thisSong` for a
    /// still-untitled draft. Mirrors the design's `songRef`.
    func songRef(title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self[.thisSong] }
        return self[.openQuote] + trimmed + self[.closeQuote]
    }

    func label(for mode: AppearanceMode) -> String {
        switch mode {
        case .light: return self[.light]
        case .dark: return self[.dark]
        case .auto: return self[.auto]
        }
    }

    func label(for theme: AccentTheme) -> String {
        switch theme {
        case .teal: return self[.accentTeal]
        case .marine: return self[.accentMarine]
        case .clay: return self[.accentClay]
        case .plum: return self[.accentPlum]
        }
    }

    func label(for order: SongSortOrder) -> String {
        switch order {
        case .alphabetical: return self[.sortAlphabet]
        case .mostRecent: return self[.sortMostRecent]
        case .oldestFirst: return self[.sortOldestFirst]
        }
    }

    /// "song"/"songs" (and equivalents) correctly pluralized for the import
    /// confirmation's song counts — Russian/Ukrainian use the standard
    /// one/few/many cardinal-plural rule, the rest a simple singular/plural.
    func songNoun(count: Int) -> String {
        switch language {
        case .en: return count == 1 ? "song" : "songs"
        case .fr: return count == 1 ? "morceau" : "morceaux"
        case .de: return count == 1 ? "Song" : "Songs"
        case .es: return count == 1 ? "canción" : "canciones"
        case .ru: return Self.slavicPlural(count, one: "песня", few: "песни", many: "песен")
        case .uk: return Self.slavicPlural(count, one: "пісня", few: "пісні", many: "пісень")
        }
    }

    private static func slavicPlural(_ count: Int, one: String, few: String, many: String) -> String {
        let mod10 = count % 10, mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return few }
        return many
    }

    /// "Importing will replace your current N song(s) with M song(s) from
    /// this backup. This can't be undone."
    func importingWillReplace(currentCount: Int, importedCount: Int) -> String {
        format(
            .importingWillReplace,
            String(currentCount), songNoun(count: currentCount),
            String(importedCount), songNoun(count: importedCount)
        )
    }

    static let tables: [AppLanguage: [LKey: String]] = [
        .en: [
            .search: "Search songs and tags", .all: "All", .delete: "Delete", .noTags: "No tags",
            .emptyNone: "No songs yet — tap + to add your first one.",
            .emptyTag: "No songs tagged %@.", .emptyQuery: "Nothing matches \u{201C}%@\u{201D}.", .or: "or",
            .untitled: "Untitled song", .save: "Save", .tagOne: "Tag", .addTags: "Add tags",
            .transposeHeader: "TRANSPOSE", .detectKey: "Detect key", .fixKey: "Fix key", .now: "NOW",
            .notEnough: "Not enough chords yet.", .notEnoughNote: "Type at least three chords and try again.",
            .fits: "These chords fit %@ \u{2014} the key looks right.", .looks: "These chords look like %@.",
            .couldBe: "Could also be %@.", .badgeSays: "The badge says %@. Chords stay as they are.",
            .majorSuffix: "%@ major", .minorSuffix: "%@ minor",
            .startHint: "Tap here to start \u{2014} type chords and, if you like, a word or two to find your place.",
            .insertChord: "INSERT CHORD", .variants: "VARIANTS",
            .hideKeyboard: "Hide keyboard", .allChords: "All chords", .done: "Done",
            .tagsHeader: "Tags", .findTag: "Find or create a tag", .create: "Create",
            .sheetEmpty: "No tag called \u{201C}%@\u{201D} yet \u{2014} Create adds it and puts it on this song.",
            .keepChanges: "Keep your changes?", .unsaved: "%@ has unsaved edits.", .thisSong: "This song",
            .discard: "Discard", .saved: "Saved",
            .library: "LIBRARY", .importSongs: "Import songs", .exportSongs: "Export songs",
            .appearance: "APPEARANCE", .light: "Light", .dark: "Dark", .auto: "Auto",
            .language: "LANGUAGE", .deviceAsks: "Your device asks for %@.",
            .deviceMissing: "Your device asks for %@ \u{2014} not translated yet, so English.",
            .sortHeader: "SORT", .sortAlphabet: "Alphabet", .sortMostRecent: "Most recent", .sortOldestFirst: "Oldest first",
            .cancel: "Cancel", .deleteConfirmTitle: "Delete %@?", .cantUndo: "This can't be undone.",
            .replaceLibraryTitle: "Replace your library?", .replaceButton: "Replace",
            .importingWillReplace: "Importing will replace your current %@ %@ with %@ %@ from this backup. This can't be undone.",
            .importFailedTitle: "Import failed", .ok: "OK",
            .couldntPrepareExport: "Couldn't prepare your library for export. Please try again.",
            .couldntOpenFile: "Couldn't open that file. Please try again.",
            .couldntReadFile: "Couldn't read that file. Please try again.",
            .backupCorrupt: "That file doesn't look like a Chord Sheet backup.",
            .backupUnsupportedVersion: "This backup was made with a newer version of Chord Sheet and can't be opened here.",
            .unpinAll: "Unpin all", .pin: "Pin", .unpin: "Unpin",
            .openQuote: "\u{201C}", .closeQuote: "\u{201D}",
            .accentTeal: "TEAL", .accentMarine: "MARINE", .accentClay: "CLAY", .accentPlum: "PLUM"
        ],
        .fr: [
            .search: "Rechercher un morceau ou un tag", .all: "Tous", .delete: "Supprimer", .noTags: "Aucun tag",
            .emptyNone: "Aucun morceau \u{2014} touchez + pour ajouter le premier.",
            .emptyTag: "Aucun morceau avec le tag %@.", .emptyQuery: "Rien ne correspond à «\u{00A0}%@\u{00A0}».", .or: "ou",
            .untitled: "Morceau sans titre", .save: "Enregistrer", .tagOne: "Tag", .addTags: "Ajouter des tags",
            .transposeHeader: "TRANSPOSER", .detectKey: "Détecter la tonalité", .fixKey: "Corriger", .now: "ACTUEL",
            .notEnough: "Pas encore assez d\u{2019}accords.", .notEnoughNote: "Saisissez au moins trois accords, puis réessayez.",
            .fits: "Ces accords correspondent à %@ \u{2014} la tonalité est bonne.", .looks: "Ces accords ressemblent à %@.",
            .couldBe: "Ce pourrait aussi être %@.", .badgeSays: "L\u{2019}étiquette indique %@. Les accords ne changent pas.",
            .majorSuffix: "%@ majeur", .minorSuffix: "%@ mineur",
            .startHint: "Touchez ici pour commencer \u{2014} tapez des accords et, si vous voulez, un mot ou deux pour vous repérer.",
            .insertChord: "INSÉRER UN ACCORD", .variants: "VARIANTES",
            .hideKeyboard: "Masquer le clavier", .allChords: "Tous les accords", .done: "Terminé",
            .tagsHeader: "Tags", .findTag: "Chercher ou créer un tag", .create: "Créer",
            .sheetEmpty: "Aucun tag «\u{00A0}%@\u{00A0}» \u{2014} Créer l\u{2019}ajoute et l\u{2019}applique à ce morceau.",
            .keepChanges: "Conserver vos modifications\u{00A0}?", .unsaved: "%@ a des modifications non enregistrées.", .thisSong: "Ce morceau",
            .discard: "Abandonner", .saved: "Enregistré",
            .library: "BIBLIOTHÈQUE", .importSongs: "Importer des morceaux", .exportSongs: "Exporter des morceaux",
            .appearance: "APPARENCE", .light: "Clair", .dark: "Sombre", .auto: "Auto",
            .language: "LANGUE", .deviceAsks: "Votre appareil demande %@.",
            .deviceMissing: "Votre appareil demande %@ \u{2014} pas encore traduit, donc anglais.",
            .sortHeader: "TRI", .sortAlphabet: "Alphabétique", .sortMostRecent: "Ajoutés récemment", .sortOldestFirst: "Les plus anciens",
            .cancel: "Annuler", .deleteConfirmTitle: "Supprimer %@\u{00A0}?", .cantUndo: "Cette action est irréversible.",
            .replaceLibraryTitle: "Remplacer votre bibliothèque\u{00A0}?", .replaceButton: "Remplacer",
            .importingWillReplace: "L\u{2019}importation remplacera vos %@ %@ actuels par les %@ %@ de cette sauvegarde. Cette action est irréversible.",
            .importFailedTitle: "Échec de l\u{2019}importation", .ok: "OK",
            .couldntPrepareExport: "Impossible de préparer votre bibliothèque pour l\u{2019}exportation. Réessayez.",
            .couldntOpenFile: "Impossible d\u{2019}ouvrir ce fichier. Réessayez.",
            .couldntReadFile: "Impossible de lire ce fichier. Réessayez.",
            .backupCorrupt: "Ce fichier ne ressemble pas à une sauvegarde Chord Sheet.",
            .backupUnsupportedVersion: "Cette sauvegarde provient d\u{2019}une version plus récente de Chord Sheet et ne peut pas être ouverte ici.",
            .unpinAll: "Tout désépingler", .pin: "Épingler", .unpin: "Désépingler",
            .openQuote: "«\u{00A0}", .closeQuote: "\u{00A0}»",
            .accentTeal: "TURQUOISE", .accentMarine: "MARINE", .accentClay: "ARGILE", .accentPlum: "PRUNE"
        ],
        .de: [
            .search: "Songs und Tags suchen", .all: "Alle", .delete: "Löschen", .noTags: "Keine Tags",
            .emptyNone: "Noch keine Songs \u{2014} auf + tippen für den ersten.",
            .emptyTag: "Keine Songs mit dem Tag %@.", .emptyQuery: "Nichts passt zu \u{201E}%@\u{201C}.", .or: "oder",
            .untitled: "Song ohne Titel", .save: "Sichern", .tagOne: "Tag", .addTags: "Tags hinzufügen",
            .transposeHeader: "TRANSPONIEREN", .detectKey: "Tonart erkennen", .fixKey: "Korrigieren", .now: "JETZT",
            .notEnough: "Noch zu wenige Akkorde.", .notEnoughNote: "Mindestens drei Akkorde eingeben, dann erneut versuchen.",
            .fits: "Diese Akkorde passen zu %@ \u{2014} die Tonart stimmt.", .looks: "Diese Akkorde klingen nach %@.",
            .couldBe: "Könnte auch %@ sein.", .badgeSays: "Das Feld zeigt %@. Die Akkorde bleiben unverändert.",
            .majorSuffix: "%@-Dur", .minorSuffix: "%@-Moll",
            .startHint: "Hier tippen und loslegen \u{2014} Akkorde schreiben und, wenn du magst, ein, zwei Wörter zur Orientierung.",
            .insertChord: "AKKORD EINFÜGEN", .variants: "VARIANTEN",
            .hideKeyboard: "Tastatur ausblenden", .allChords: "Alle Akkorde", .done: "Fertig",
            .tagsHeader: "Tags", .findTag: "Tag finden oder anlegen", .create: "Anlegen",
            .sheetEmpty: "Kein Tag \u{201E}%@\u{201C} \u{2014} Anlegen erstellt ihn und setzt ihn auf diesen Song.",
            .keepChanges: "Änderungen behalten?", .unsaved: "%@ hat ungesicherte Änderungen.", .thisSong: "Dieser Song",
            .discard: "Verwerfen", .saved: "Gesichert",
            .library: "BIBLIOTHEK", .importSongs: "Songs importieren", .exportSongs: "Songs exportieren",
            .appearance: "DARSTELLUNG", .light: "Hell", .dark: "Dunkel", .auto: "Auto",
            .language: "SPRACHE", .deviceAsks: "Dein Gerät möchte %@.",
            .deviceMissing: "Dein Gerät möchte %@ \u{2014} noch nicht übersetzt, daher Englisch.",
            .sortHeader: "SORTIERUNG", .sortAlphabet: "Alphabetisch", .sortMostRecent: "Zuletzt hinzugefügt", .sortOldestFirst: "Älteste zuerst",
            .cancel: "Abbrechen", .deleteConfirmTitle: "%@ löschen?", .cantUndo: "Das kann nicht rückgängig gemacht werden.",
            .replaceLibraryTitle: "Deine Bibliothek ersetzen?", .replaceButton: "Ersetzen",
            .importingWillReplace: "Der Import ersetzt deine aktuellen %@ %@ durch die %@ %@ aus dieser Sicherung. Das kann nicht rückgängig gemacht werden.",
            .importFailedTitle: "Import fehlgeschlagen", .ok: "OK",
            .couldntPrepareExport: "Deine Bibliothek konnte nicht für den Export vorbereitet werden. Bitte erneut versuchen.",
            .couldntOpenFile: "Diese Datei konnte nicht geöffnet werden. Bitte erneut versuchen.",
            .couldntReadFile: "Diese Datei konnte nicht gelesen werden. Bitte erneut versuchen.",
            .backupCorrupt: "Diese Datei sieht nicht wie eine Chord-Sheet-Sicherung aus.",
            .backupUnsupportedVersion: "Diese Sicherung stammt von einer neueren Chord-Sheet-Version und kann hier nicht geöffnet werden.",
            .unpinAll: "Alle lösen", .pin: "Anheften", .unpin: "Lösen",
            .openQuote: "\u{201E}", .closeQuote: "\u{201C}",
            .accentTeal: "TÜRKIS", .accentMarine: "MARINE", .accentClay: "TON", .accentPlum: "PFLAUME"
        ],
        .es: [
            .search: "Buscar canciones y etiquetas", .all: "Todas", .delete: "Eliminar", .noTags: "Sin etiquetas",
            .emptyNone: "Aún no hay canciones \u{2014} toca + para añadir la primera.",
            .emptyTag: "Ninguna canción con la etiqueta %@.", .emptyQuery: "Nada coincide con «%@».", .or: "o",
            .untitled: "Canción sin título", .save: "Guardar", .tagOne: "Etiqueta", .addTags: "Añadir etiquetas",
            .transposeHeader: "TRANSPORTAR", .detectKey: "Detectar tonalidad", .fixKey: "Corregir", .now: "AHORA",
            .notEnough: "Aún faltan acordes.", .notEnoughNote: "Escribe al menos tres acordes e inténtalo otra vez.",
            .fits: "Estos acordes encajan en %@ \u{2014} la tonalidad es correcta.", .looks: "Estos acordes suenan a %@.",
            .couldBe: "También podría ser %@.", .badgeSays: "La etiqueta dice %@. Los acordes no cambian.",
            .majorSuffix: "%@ mayor", .minorSuffix: "%@ menor",
            .startHint: "Toca aquí para empezar \u{2014} escribe acordes y, si quieres, una palabra o dos para orientarte.",
            .insertChord: "INSERTAR ACORDE", .variants: "VARIANTES",
            .hideKeyboard: "Ocultar teclado", .allChords: "Todos los acordes", .done: "Listo",
            .tagsHeader: "Etiquetas", .findTag: "Buscar o crear una etiqueta", .create: "Crear",
            .sheetEmpty: "No existe la etiqueta «%@» \u{2014} Crear la añade y la pone en esta canción.",
            .keepChanges: "¿Guardar los cambios?", .unsaved: "%@ tiene cambios sin guardar.", .thisSong: "Esta canción",
            .discard: "Descartar", .saved: "Guardado",
            .library: "BIBLIOTECA", .importSongs: "Importar canciones", .exportSongs: "Exportar canciones",
            .appearance: "APARIENCIA", .light: "Claro", .dark: "Oscuro", .auto: "Auto",
            .language: "IDIOMA", .deviceAsks: "Tu dispositivo pide %@.",
            .deviceMissing: "Tu dispositivo pide %@ \u{2014} sin traducción, así que inglés.",
            .sortHeader: "ORDEN", .sortAlphabet: "Alfabético", .sortMostRecent: "Añadidas hace poco", .sortOldestFirst: "Las más antiguas",
            .cancel: "Cancelar", .deleteConfirmTitle: "¿Eliminar %@?", .cantUndo: "Esto no se puede deshacer.",
            .replaceLibraryTitle: "¿Reemplazar tu biblioteca?", .replaceButton: "Reemplazar",
            .importingWillReplace: "Importar reemplazará tus %@ %@ actuales por las %@ %@ de esta copia de seguridad. Esto no se puede deshacer.",
            .importFailedTitle: "Error al importar", .ok: "Aceptar",
            .couldntPrepareExport: "No se pudo preparar tu biblioteca para exportar. Inténtalo de nuevo.",
            .couldntOpenFile: "No se pudo abrir ese archivo. Inténtalo de nuevo.",
            .couldntReadFile: "No se pudo leer ese archivo. Inténtalo de nuevo.",
            .backupCorrupt: "Ese archivo no parece una copia de seguridad de Chord Sheet.",
            .backupUnsupportedVersion: "Esta copia de seguridad se creó con una versión más reciente de Chord Sheet y no se puede abrir aquí.",
            .unpinAll: "Desanclar todo", .pin: "Anclar", .unpin: "Desanclar",
            .openQuote: "«", .closeQuote: "»",
            .accentTeal: "TURQUESA", .accentMarine: "MARINO", .accentClay: "ARCILLA", .accentPlum: "CIRUELA"
        ],
        .ru: [
            .search: "Поиск песен и тегов", .all: "Все", .delete: "Удалить", .noTags: "Без тегов",
            .emptyNone: "Песен пока нет \u{2014} нажмите +, чтобы добавить первую.",
            .emptyTag: "Нет песен с тегом %@.", .emptyQuery: "Ничего не найдено по «%@».", .or: "или",
            .untitled: "Без названия", .save: "Сохранить", .tagOne: "Тег", .addTags: "Добавить теги",
            .transposeHeader: "ТРАНСПОНИРОВАТЬ", .detectKey: "Определить тональность", .fixKey: "Исправить", .now: "СЕЙЧАС",
            .notEnough: "Пока мало аккордов.", .notEnoughNote: "Введите хотя бы три аккорда и попробуйте снова.",
            .fits: "Аккорды подходят к %@ \u{2014} тональность верна.", .looks: "Аккорды похожи на %@.",
            .couldBe: "Может быть и %@.", .badgeSays: "На бейдже %@. Аккорды остаются как есть.",
            .majorSuffix: "%@ мажор", .minorSuffix: "%@ минор",
            .startHint: "Нажмите здесь \u{2014} пишите аккорды и, если хотите, слово-другое, чтобы не потеряться.",
            .insertChord: "ВСТАВИТЬ АККОРД", .variants: "ВАРИАНТЫ",
            .hideKeyboard: "Скрыть клавиатуру", .allChords: "Все аккорды", .done: "Готово",
            .tagsHeader: "Теги", .findTag: "Найти или создать тег", .create: "Создать",
            .sheetEmpty: "Тега «%@» ещё нет \u{2014} «Создать» добавит его и поставит на эту песню.",
            .keepChanges: "Сохранить изменения?", .unsaved: "В %@ есть несохранённые правки.", .thisSong: "этой песне",
            .discard: "Отменить", .saved: "Сохранено",
            .library: "БИБЛИОТЕКА", .importSongs: "Импорт песен", .exportSongs: "Экспорт песен",
            .appearance: "ОФОРМЛЕНИЕ", .light: "Светлая", .dark: "Тёмная", .auto: "Авто",
            .language: "ЯЗЫК", .deviceAsks: "Устройство просит %@.",
            .deviceMissing: "Устройство просит %@ \u{2014} перевода нет, поэтому английский.",
            .sortHeader: "СОРТИРОВКА", .sortAlphabet: "По алфавиту", .sortMostRecent: "Сначала новые", .sortOldestFirst: "Сначала старые",
            .cancel: "Отмена", .deleteConfirmTitle: "Удалить %@?", .cantUndo: "Это действие нельзя отменить.",
            .replaceLibraryTitle: "Заменить вашу библиотеку?", .replaceButton: "Заменить",
            .importingWillReplace: "Импорт заменит текущие %@ %@ на %@ %@ из этой резервной копии. Это действие нельзя отменить.",
            .importFailedTitle: "Ошибка импорта", .ok: "ОК",
            .couldntPrepareExport: "Не удалось подготовить библиотеку к экспорту. Попробуйте ещё раз.",
            .couldntOpenFile: "Не удалось открыть этот файл. Попробуйте ещё раз.",
            .couldntReadFile: "Не удалось прочитать этот файл. Попробуйте ещё раз.",
            .backupCorrupt: "Этот файл не похож на резервную копию Chord Sheet.",
            .backupUnsupportedVersion: "Эта резервная копия сделана в более новой версии Chord Sheet и не может быть открыта здесь.",
            .unpinAll: "Открепить все", .pin: "Закрепить", .unpin: "Открепить",
            .openQuote: "«", .closeQuote: "»",
            .accentTeal: "БИРЮЗА", .accentMarine: "МОРСКОЙ", .accentClay: "ГЛИНА", .accentPlum: "СЛИВА"
        ],
        .uk: [
            .search: "Пошук пісень і тегів", .all: "Усі", .delete: "Видалити", .noTags: "Без тегів",
            .emptyNone: "Пісень поки немає \u{2014} натисніть +, щоб додати першу.",
            .emptyTag: "Немає пісень із тегом %@.", .emptyQuery: "Нічого не знайдено за «%@».", .or: "або",
            .untitled: "Без назви", .save: "Зберегти", .tagOne: "Тег", .addTags: "Додати теги",
            .transposeHeader: "ТРАНСПОНУВАТИ", .detectKey: "Визначити тональність", .fixKey: "Виправити", .now: "ЗАРАЗ",
            .notEnough: "Поки замало акордів.", .notEnoughNote: "Введіть хоча б три акорди й спробуйте ще раз.",
            .fits: "Акорди пасують до %@ \u{2014} тональність правильна.", .looks: "Акорди схожі на %@.",
            .couldBe: "Може бути й %@.", .badgeSays: "На бейджі %@. Акорди лишаються як є.",
            .majorSuffix: "%@ мажор", .minorSuffix: "%@ мінор",
            .startHint: "Натисніть тут \u{2014} пишіть акорди і, якщо хочете, слово-два, щоб не загубитися.",
            .insertChord: "ВСТАВИТИ АКОРД", .variants: "ВАРІАНТИ",
            .hideKeyboard: "Сховати клавіатуру", .allChords: "Усі акорди", .done: "Готово",
            .tagsHeader: "Теги", .findTag: "Знайти або створити тег", .create: "Створити",
            .sheetEmpty: "Тегу «%@» ще немає \u{2014} «Створити» додасть його до цієї пісні.",
            .keepChanges: "Зберегти зміни?", .unsaved: "У %@ є незбережені правки.", .thisSong: "цій пісні",
            .discard: "Відхилити", .saved: "Збережено",
            .library: "БІБЛІОТЕКА", .importSongs: "Імпорт пісень", .exportSongs: "Експорт пісень",
            .appearance: "ОФОРМЛЕННЯ", .light: "Світла", .dark: "Темна", .auto: "Авто",
            .language: "МОВА", .deviceAsks: "Пристрій просить %@.",
            .deviceMissing: "Пристрій просить %@ \u{2014} перекладу немає, тому англійська.",
            .sortHeader: "СОРТУВАННЯ", .sortAlphabet: "За абеткою", .sortMostRecent: "Спочатку нові", .sortOldestFirst: "Спочатку старі",
            .cancel: "Скасувати", .deleteConfirmTitle: "Видалити %@?", .cantUndo: "Цю дію не можна скасувати.",
            .replaceLibraryTitle: "Замінити вашу бібліотеку?", .replaceButton: "Замінити",
            .importingWillReplace: "Імпорт замінить поточні %@ %@ на %@ %@ із цієї резервної копії. Цю дію не можна скасувати.",
            .importFailedTitle: "Помилка імпорту", .ok: "ОК",
            .couldntPrepareExport: "Не вдалося підготувати бібліотеку до експорту. Спробуйте ще раз.",
            .couldntOpenFile: "Не вдалося відкрити цей файл. Спробуйте ще раз.",
            .couldntReadFile: "Не вдалося прочитати цей файл. Спробуйте ще раз.",
            .backupCorrupt: "Цей файл не схожий на резервну копію Chord Sheet.",
            .backupUnsupportedVersion: "Цю резервну копію зроблено в новішій версії Chord Sheet, і її не можна відкрити тут.",
            .unpinAll: "Відкріпити всі", .pin: "Закріпити", .unpin: "Відкріпити",
            .openQuote: "«", .closeQuote: "»",
            .accentTeal: "БІРЮЗА", .accentMarine: "МОРСЬКИЙ", .accentClay: "ГЛИНА", .accentPlum: "СЛИВА"
        ]
    ]
}
