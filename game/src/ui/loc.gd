class_name Loc
extends RefCounted
## Localization (P3-18, docs/localization.md). The English text is the
## message id (gettext): buttons and labels with fixed text translate on
## their own; text built in code goes through Loc.t(), and names from the
## game data (units, powers, maps) are translated where they are shown.
## Translations are game/locale/<code>.po; tools/extract_strings.py keeps
## the template game/locale/messages.pot up to date. View/UI only.

## Offered in Settings, in this order. "" follows the device's language.
const LANGUAGES: Dictionary = {"": "Device language", "en": "English", "es": "Español"}


static func t(text: String) -> String:
	return TranslationServer.translate(text)


## Sets the language ("" = the device's).
static func use(code: String) -> void:
	TranslationServer.set_locale(code if code != "" else OS.get_locale_language())
