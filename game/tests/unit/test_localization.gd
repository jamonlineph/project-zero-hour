extends TestCase
# Localization (P3-18): the English text is the message id; the Spanish
# translation is loaded from the project settings; untranslated texts
# stay English; text built in code goes through Loc.t first.


func _use(code: String) -> void:
	TranslationServer.set_locale(code)


func test_spanish_is_offered_and_loaded() -> void:
	assert_true(Loc.LANGUAGES.has("es"))
	_use("es")
	assert_eq(Loc.t("Settings"), "Ajustes")
	assert_eq(Loc.t("North Korea"), "Corea del Norte")
	assert_eq(Loc.t("Credits: %d") % 500, "Créditos: 500")
	_use("en")


func test_english_and_missing_texts_stay_as_they_are() -> void:
	_use("en")
	assert_eq(Loc.t("Settings"), "Settings")
	_use("es")
	assert_eq(Loc.t("A text nobody translated"), "A text nobody translated")
	_use("en")


func test_the_language_setting_round_trips() -> void:
	var s := GameSettings.new()
	s.language = "es"
	var path: String = "user://test_settings_lang.cfg"
	s.save_to(path)
	var t := GameSettings.new()
	t.load_from(path)
	assert_eq(t.language, "es")
	DirAccess.remove_absolute(path)
	Loc.use("en")


func test_the_accessibility_settings_round_trip() -> void:
	var s := GameSettings.new()
	s.confirm_sell = false
	s.camera_shake = 1
	var path: String = "user://test_settings_a11y.cfg"
	s.save_to(path)
	var t := GameSettings.new()
	t.load_from(path)
	assert_false(t.confirm_sell)
	assert_eq(t.camera_shake, 1)
	DirAccess.remove_absolute(path)
	assert_eq(RtsCamera.shake_factor(0), 0.0, "camera shake off still shakes")
	assert_true(RtsCamera.shake_factor(1) < RtsCamera.shake_factor(2))
