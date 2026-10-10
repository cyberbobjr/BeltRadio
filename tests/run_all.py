"""Vérifications de Belt Walkie-Talkie (batman_BeltRadio), sans lancer le jeu.

    python tests/run_all.py [--require-luacheck]

1. luacheck (configuration .luacheckrc), facultatif en local, exigé par la CI ;
2. syntaxe Lua 5.1 des fichiers du mod, appels à next() (absent de Kahlua),
   littéraux non ASCII hors commentaires (changés en U+FFFD par le lexeur Kahlua) ;
3. mod.info (id, versionMin, poster et icône présents) ;
4. options sandbox : traductions de chaque option et de la page, options citées
   par le Lua (option("X") / enabled("X")) présentes dans sandbox-options.txt ;
5. traductions : JSON valides, sans BOM, mêmes clés et paramètres que EN, pas de % seul ;
6. descriptions Steam (README.steam*) : 8 000 octets UTF-8 au plus (bloc Workshop ID /
   Mod ID déduit), BBCode équilibré, mêmes liens que l'anglais, workshop.txt identique
   à README.steam, sans id= tant que l'objet n'est pas créé ;
7. casse des chemins pour un serveur Linux (tools/check_case.py), si le jeu est installé ;
8. tests Lua (tests/lua/test_*.lua) sous lupa, avec l'API du jeu simulée.

Dépendances : pip install lupa. Les vérifications qui lisent le jeu installé
(PZ_MEDIA) ou Better Walkie Talkies (BWT_LUA) sont ignorées s'ils sont absents.
"""

import json
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lua_harness  # noqa: E402

REPO = lua_harness.REPO
MOD_DIR = lua_harness.MOD_DIR
MOD_MEDIA = lua_harness.MOD_MEDIA
MOD_LUA = lua_harness.MOD_LUA
TRANSLATE = MOD_LUA / "shared" / "Translate"
REFERENCE_LANGUAGE = "EN"
MOD_ID = "batman_BeltRadio"
OPTION_PAGE = "BeltRadio"
# Langues de Military Drop (Translate/), reprises ici.
LANGUAGES = ("CN", "DE", "EN", "ES", "FR", "PT", "PTBR", "RU")

BARE_NEXT = re.compile(r"(?<![.:\w])next\s*\(")
TOKEN = re.compile(r"%\d|%%|<LINE>|<RGB:[^>]*>")
LONE_PERCENT = re.compile(r"%(?!\d)")
STEAM_DESCRIPTION_MAX_BYTES = 8000
STEAM_TAGS = ("h1", "h2", "h3", "b", "i", "u", "list", "olist", "table", "tr", "td", "url", "img")
STEAM_URL = re.compile(r"\[url=([^\]]+)\]|\[img\]([^\[]+)\[/img\]")
OPTION_USE = re.compile(r"\b(?:option|enabled)\(\s*\"(\w+)\"\s*\)")


class Report:
    def __init__(self):
        self.failures = 0

    def section(self, title):
        print(f"\n== {title}")

    def ok(self, message):
        print(f"  ok    {message}")

    def skip(self, message):
        print(f"  --    {message}")

    def fail(self, message):
        self.failures += 1
        print(f"  ÉCHEC {message}")


def mod_lua_files():
    return sorted(MOD_LUA.rglob("*.lua"))


def strip_comments(line):
    # Suffisant pour ce code : aucune chaîne ne contient « -- ».
    return line.split("--", 1)[0]


def check_luacheck(report, required):
    report.section("luacheck")
    exe = shutil.which("luacheck")
    if not exe:
        if required:
            report.fail("luacheck introuvable")
        else:
            report.skip("luacheck introuvable (ignoré en local, exigé par la CI)")
        return
    result = subprocess.run([exe, "--formatter", "plain", "Contents", "tests"], cwd=REPO,
                            capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode == 0:
        report.ok("aucun avertissement")
        return
    for line in (result.stdout + result.stderr).strip().splitlines():
        report.fail(line)


def check_kahlua(report):
    report.section("Syntaxe Lua 5.1 et contraintes de Kahlua")
    files = mod_lua_files()
    errors = lua_harness.compile_errors(files)
    for error in errors:
        report.fail(error)
    if not errors:
        report.ok(f"{len(files)} fichiers compilés ({lua_harness.LUA_VERSION})")
    before = report.failures
    for path in files:
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = strip_comments(line)
            where = f"{path.relative_to(REPO)}:{number}"
            if BARE_NEXT.search(code):
                report.fail(f"{where} : next() n'existe pas dans Kahlua")
            if any(ord(char) > 127 for char in code):
                report.fail(f"{where} : caractère non ASCII hors commentaire (U+FFFD dans Kahlua)")
            if re.search(r"\bgoto\b", code):
                report.fail(f"{where} : goto absent de Lua 5.1")
    if report.failures == before:
        report.ok("ni next(), ni goto, ni littéral non ASCII")


def read_mod_info(path):
    info = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            info[key.strip()] = value.strip()
    return info


def check_mod_info(report):
    report.section("mod.info")
    infos = sorted(MOD_DIR.glob("*/mod.info"))
    if [p.parent.name for p in infos] != ["42.21"]:
        report.fail(f"mod.info attendu dans 42.21 seulement, trouvé : {[str(p.relative_to(REPO)) for p in infos]}")
        return
    if not (MOD_DIR / "common").is_dir():
        report.fail("dossier common/ absent (exigé en Build 42)")
    info = read_mod_info(infos[0])
    before = report.failures
    if info.get("id") != MOD_ID:
        report.fail(f"id={info.get('id')} (attendu {MOD_ID})")
    if info.get("versionMin") != "42.21":
        report.fail("versionMin=42.21 attendu")
    if "versionMax" in info:
        report.fail("versionMax rend le mod inactivable à la prochaine version du jeu")
    if "require" in info:
        report.fail("le mod commun ne dépend d'aucun autre mod")
    for key in ("poster", "icon"):
        if not (infos[0].parent / info.get(key, "?")).is_file():
            report.fail(f"{key}={info.get(key)} introuvable à côté de mod.info")
    if not re.match(r"^\d+\.\d+\.\d+$", info.get("modversion", "")):
        report.fail("modversion=X.Y.Z attendu")
    changelog = (REPO / "CHANGELOG.md").read_text(encoding="utf-8")
    top = re.search(r"^## (\d+\.\d+\.\d+)", changelog, re.M)
    if not top or top.group(1) != info.get("modversion"):
        report.fail("première version de CHANGELOG.md différente de modversion")
    if report.failures == before:
        report.ok(f"{info['id']} {info['modversion']}, versionMin {info['versionMin']}")


def load_json(path, report):
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        report.fail(f"{path.relative_to(REPO)} : BOM UTF-8")
    try:
        data = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        report.fail(f"{path.relative_to(REPO)} : JSON invalide ({error})")
        return None
    if not isinstance(data, dict) or not all(isinstance(v, str) for v in data.values()):
        report.fail(f"{path.relative_to(REPO)} : objet plat de chaînes attendu")
        return None
    return data


def sandbox_options():
    text = (MOD_MEDIA / "sandbox-options.txt").read_text(encoding="utf-8")
    return re.findall(r"^option " + OPTION_PAGE + r"\.(\w+)", text, flags=re.M), text


def check_sandbox(report):
    report.section("Options sandbox")
    options, text = sandbox_options()
    before = report.failures
    if not text.startswith("VERSION = 1,"):
        report.fail("sandbox-options.txt doit commencer par VERSION = 1,")
    if "//" in text:
        report.fail("commentaire // interdit (lignes concaténées par le parseur)")
    for block in re.findall(r"option \w+\.\w+\s*\{(.*?)\}", text, re.S):
        if "type = boolean" in block and "default =" not in block:
            report.fail("option booléenne sans default")
        if f"page = {OPTION_PAGE}" not in block:
            report.fail(f"option hors de la page {OPTION_PAGE}")
    keys = json.loads((TRANSLATE / REFERENCE_LANGUAGE / "Sandbox.json").read_text(encoding="utf-8"))
    for key in [f"Sandbox_{OPTION_PAGE}"] + [f"Sandbox_{OPTION_PAGE}_{name}{suffix}"
                                              for name in options for suffix in ("", "_tooltip")]:
        if key not in keys:
            report.fail(f"traduction {key} absente de {REFERENCE_LANGUAGE}/Sandbox.json")
    used = set()
    for path in mod_lua_files():
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for name in OPTION_USE.findall(strip_comments(line)):
                used.add(name)
                if name not in options:
                    report.fail(f"{path.relative_to(REPO)}:{number} : option {name} absente de sandbox-options.txt")
    defaults = (MOD_LUA / "shared/BatmanRadio/BatmanRadio_Support.lua").read_text(encoding="utf-8")
    for name in options:
        if name not in used:
            report.fail(f"option {name} jamais lue par le Lua")
        if not re.search(r"OPTION_DEFAULTS = \{[^}]*\b" + name + r" = true", defaults):
            report.fail(f"option {name} sans valeur par défaut true dans OPTION_DEFAULTS")
    if report.failures == before:
        report.ok(f"{len(options)} options ({', '.join(options)}) lues, traduites, défaut true")


def check_translations(report):
    report.section("Traductions")
    folders = sorted(p.name for p in TRANSLATE.iterdir() if p.is_dir())
    if tuple(folders) != LANGUAGES:
        report.fail(f"langues {folders}, attendu {list(LANGUAGES)} (celles de Military Drop)")
    reference = {}
    for path in sorted((TRANSLATE / REFERENCE_LANGUAGE).glob("*.json")):
        data = load_json(path, report)
        if data is not None:
            reference[path.name] = data
    for language in folders:
        before = report.failures
        folder = TRANSLATE / language
        names = {p.name for p in folder.glob("*.json")}
        for missing in sorted(set(reference) - names):
            report.fail(f"{language} : {missing} manquant")
        for extra in sorted(names - set(reference)):
            report.fail(f"{language} : {extra} absent de {REFERENCE_LANGUAGE}")
        for name in sorted(names & set(reference)):
            path = folder / name
            data = load_json(path, report)
            if data is None:
                continue
            expected = reference[name]
            for key in sorted(set(expected) ^ set(data)):
                report.fail(f"{language}/{name} : clé {'manquante' if key in expected else 'en trop'} {key}")
            for key, value in data.items():
                if LONE_PERCENT.search(value.replace("%%", "")):
                    report.fail(f"{language}/{name} {key} : % seul (écrire %%)")
                if key in expected and Counter(TOKEN.findall(value)) != Counter(TOKEN.findall(expected[key])):
                    report.fail(f"{language}/{name} {key} : paramètres différents de {REFERENCE_LANGUAGE}")
        if report.failures == before:
            report.ok(f"{language} : {sum(len(d) for d in reference.values())} clés conformes")


def check_steam_descriptions(report):
    report.section("Descriptions Steam")
    reference = (REPO / "README.steam").read_text(encoding="utf-8")
    reference_urls = Counter(STEAM_URL.findall(reference))
    workshop = (REPO / "workshop.txt").read_text(encoding="utf-8").splitlines()
    workshop_id = next((line[3:] for line in workshop if line.startswith("id=")), "")
    # Bloc ajouté à chaque langue par les outils de publication (Workshop ID / Mod ID).
    suffix = len(("\n\nWorkshop ID: " + (workshop_id or "0" * 10) + "\nMod ID: " + MOD_ID).encode("utf-8"))
    for path in sorted(REPO.glob("README.steam*")):
        text = path.read_text(encoding="utf-8")
        before = report.failures
        size = len(text.encode("utf-8"))
        if size > STEAM_DESCRIPTION_MAX_BYTES - suffix:
            report.fail(f"{path.name} : {size} octets UTF-8 (Steam : {STEAM_DESCRIPTION_MAX_BYTES - suffix} au plus)")
        for tag in STEAM_TAGS:
            opened = len(re.findall(r"\[" + tag + r"(?:=[^\]]*)?\]", text))
            if opened != text.count(f"[/{tag}]"):
                report.fail(f"{path.name} : [{tag}] ouvert {opened} fois, fermé {text.count(f'[/{tag}]')} fois")
        if Counter(STEAM_URL.findall(text)) != reference_urls:
            report.fail(f"{path.name} : liens ou images différents de README.steam")
        if "github.com" in text.lower():
            report.fail(f"{path.name} : lien GitHub alors que le dépôt n'est pas public")
        if report.failures == before:
            report.ok(f"{path.name} : {size} octets")
    description = [line[len("description="):] for line in workshop if line.startswith("description=")]
    if description != reference.splitlines():
        report.fail("workshop.txt : description différente de README.steam")
    else:
        report.ok("workshop.txt : description identique à README.steam")
    fields = {line.split("=", 1)[0] for line in workshop if "=" in line}
    if "visibility=public" not in workshop:
        report.fail("workshop.txt : visibility=public attendu")
    if not {"version", "title", "tags", "visibility"} <= fields:
        report.fail("workshop.txt : version, title, tags et visibility attendus")
    try:
        from PIL import Image
    except ImportError:
        report.skip("Pillow absent : preview.png non vérifié")
        return
    with Image.open(REPO / "preview.png") as image:
        if image.size not in ((256, 256), (512, 512)) or (REPO / "preview.png").stat().st_size > 1024000:
            report.fail(f"preview.png : {image.size}, PNG carré 256 ou 512 px de 1 024 000 octets au plus")
        else:
            report.ok(f"preview.png : {image.size[0]} x {image.size[1]}")


def check_case(report):
    report.section("Casse des chemins (serveur Linux)")
    if not lua_harness.PZ_MEDIA.is_dir():
        report.skip("jeu absent (PZ_MEDIA) : tools/check_case.py non lancé")
        return
    result = subprocess.run([sys.executable, str(REPO / "tools" / "check_case.py"),
                             "--vanilla", str(lua_harness.PZ_MEDIA)],
                            capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = (result.stdout + result.stderr).strip().splitlines()
    if result.returncode == 0:
        report.ok(lines[0] if lines else "tools/check_case.py")
    else:
        for line in lines:
            report.fail(line)


def check_lua_tests(report):
    report.section(f"Tests Lua ({lua_harness.LUA_VERSION})")
    for path in sorted((Path(__file__).parent / "lua").glob("test_*.lua")):
        for name, error, skipped in lua_harness.run_test_file(path):
            label = f"{path.stem} : {name}"
            if skipped:
                report.skip(f"{label} ({error})")
            elif error:
                report.fail(f"{label}\n        {error}")
            else:
                report.ok(label)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    report = Report()
    check_luacheck(report, "--require-luacheck" in sys.argv)
    check_kahlua(report)
    check_mod_info(report)
    check_sandbox(report)
    check_translations(report)
    check_steam_descriptions(report)
    check_case(report)
    check_lua_tests(report)
    print()
    if report.failures:
        print(f"{report.failures} échec(s)")
        return 1
    print("Tout est bon.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
