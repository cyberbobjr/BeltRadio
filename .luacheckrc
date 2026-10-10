-- Luacheck : Lua 5.1, le langage de Kahlua (Project Zomboid).
std = "lua51"
-- Les globales du jeu (Events, getText, ISRadioWindow...) et des tests simulés
-- sont trop nombreuses pour être listées : on ne contrôle pas les globales.
-- Globales du mod : BatmanRadioSupport, BatmanBeltRadioBattery.
global = false
-- Les signatures vanilla imposent souvent des paramètres inutilisés.
unused_args = false
codes = true
max_line_length = 130
