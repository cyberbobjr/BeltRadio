"""Copies de secours de Belt Walkie-Talkie dans les mods qui ne l'exigent pas.

    python tools/sync_fallback.py [--check] [MilitaryDrop] [OperationArtemis]

Military Drop et Opération Artemis utilisent batman_BeltRadio s'il est activé,
sinon leur copie embarquée (décision 7, docs/API.md « Copie de secours »).
Chaque copie est générée depuis les fichiers de ce mod :
- rangée sous un chemin propre au mod (<préfixe> = MilitaryDrop/BeltRadioFallback,
  Artemis/BeltRadioFallback), jamais sous BatmanRadio/ (elle masquerait ce mod) ;
- précédée d'une garde qui ne fait rien (ni globale, ni événement) si
  batman_BeltRadio est activé ;
- ses require "BatmanRadio/..." réécrits vers "<préfixe>/...".
Le reste du code est identique (fins de ligne mises à part). --check compare sans écrire
(utilisé par les tests de chaque mod, qui importent ce module).
"""

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WORKSPACE = REPO.parent
MOD_ID = "batman_BeltRadio"
SOURCE = REPO / "Contents" / "mods" / MOD_ID / "42.21" / "media" / "lua"
MOD_INFO = REPO / "Contents" / "mods" / MOD_ID / "42.21" / "mod.info"
# (dossier sous media/lua, nom du module) : chemin source <scope>/BatmanRadio/<nom>.lua.
MODULES = (
    ("client", "BatmanRadio_Core"),
    ("client", "BatmanRadio_BeltBattery"),
    ("shared", "BatmanRadio_Support"),
    ("shared", "BatmanRadio_Compat"),
)
# Projet -> (media/lua du mod, préfixe des modules de secours).
TARGETS = {
    "MilitaryDrop": (WORKSPACE / "MilitaryDrop/Contents/mods/batman_MilitaryDrop/42.21/media/lua",
                     "MilitaryDrop/BeltRadioFallback"),
    "OperationArtemis": (WORKSPACE / "OperationArtemis/Contents/mods/batman_OperationArtemis/42.21/media/lua",
                         "Artemis/BeltRadioFallback"),
}
REQUIRE = re.compile(r'require\s*\(?\s*"BatmanRadio/')

HEADER = """\
-- Copie de secours de Belt Walkie-Talkie ({mod_id} {version}), générée par
-- BeltRadio/tools/sync_fallback.py depuis media/lua/{source} :
-- ne pas modifier ici. Elle ne fait rien si {mod_id} est activé (le mod
-- commun s'en charge) ; sinon elle garde les globales BatmanRadioSupport et
-- BatmanBeltRadioBattery, si bien que deux copies de secours (deux mods sans
-- {mod_id}) se remplacent au lieu de s'additionner.
local beltRadioActive = false
do
    local mods = getActivatedMods and getActivatedMods()
    for i = 0, (mods and mods:size() or 0) - 1 do
        if string.gsub(mods:get(i), "^\\\\", "") == "{mod_id}" then beltRadioActive = true end
    end
end
if beltRadioActive then return end

"""


def version():
    for line in MOD_INFO.read_text(encoding="utf-8").splitlines():
        if line.startswith("modversion="):
            return line.split("=", 1)[1].strip()
    return "?"


def render(scope, name, prefix):
    """Texte de la copie de secours d'un module."""
    rel = f"{scope}/BatmanRadio/{name}.lua"
    source = (SOURCE / rel).read_text(encoding="utf-8")
    body = REQUIRE.sub(lambda m: m.group(0).replace("BatmanRadio/", prefix + "/"), source)
    if REQUIRE.search(body):
        raise SystemExit(f"require BatmanRadio/ restant dans {rel}")
    return HEADER.format(mod_id=MOD_ID, version=version(), source=rel) + body


def expected(project):
    """{chemin de la copie : texte attendu} pour un projet."""
    lua, prefix = TARGETS[project]
    return {lua / scope / prefix / f"{name}.lua": render(scope, name, prefix) for scope, name in MODULES}


def check(project):
    """Écarts entre les copies d'un projet et ce mod (liste vide si identiques)."""
    lua, prefix = TARGETS[project]
    wanted = expected(project)
    errors = []
    for path, text in wanted.items():
        if not path.is_file():
            errors.append(f"copie absente : {path}")
        # Fins de ligne ignorées (core.autocrlf peut extraire en CRLF).
        elif path.read_text(encoding="utf-8") != text:
            errors.append(f"copie divergente : {path}")
    for scope in ("client", "shared", "server"):
        folder = lua / scope / prefix
        for path in sorted(folder.rglob("*")) if folder.is_dir() else []:
            if path.is_file() and path not in wanted:
                errors.append(f"fichier en trop : {path}")
        old = lua / scope / "BatmanRadio"
        if old.is_dir():
            errors.append(f"ancienne copie au chemin du mod commun (le masquerait) : {old}")
    return errors


def sync(project):
    for path, text in expected(project).items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode("utf-8"))


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="comparer sans écrire")
    parser.add_argument("projects", nargs="*", help="projets (" + ", ".join(TARGETS) + ") ; défaut : ceux présents")
    args = parser.parse_args()
    unknown = [p for p in args.projects if p not in TARGETS]
    if unknown:
        parser.error("projet inconnu : " + ", ".join(unknown))
    projects = args.projects or [p for p in TARGETS if TARGETS[p][0].is_dir()]
    failures = []
    for project in projects:
        if not args.check:
            sync(project)
        errors = check(project)
        failures += errors
        print(f"{project} : " + ("copies identiques" if not errors else f"{len(errors)} écart(s)"))
    for error in failures:
        print("  " + error)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
