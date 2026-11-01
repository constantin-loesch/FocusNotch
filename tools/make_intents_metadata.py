#!/usr/bin/env python3
"""Erzeugt Metadata.appintents für das Widget (macht sonst Xcode beim Bauen).

Aufruf: make_intents_metadata.py <widget-binary> <ausgabe-ordner>
Ohne diese Datei erkennt macOS die Widget-Buttons (App Intents) nicht.
"""
import json, os, re, subprocess, sys

binary, out_dir = sys.argv[1], sys.argv[2]
MODULE = "FocusNotchWidget"
TITLES = {
    "ToggleTimerIntent": "Timer starten oder anhalten",
    "SkipTimerIntent": "Timer überspringen",
    "StopTimerIntent": "Timer stoppen",
}

# Echte (gemangelte) Swift-Typnamen aus dem Binary lesen
symbols = subprocess.run(["nm", binary], capture_output=True, text=True, check=True).stdout
mangled = {}
for m in re.finditer(r"_\$s(\d+%s\d+(\w+?Intent)V)Mn\b" % MODULE, symbols):
    mangled[m.group(2)] = m.group(1)

actions = {}
for name, title in TITLES.items():
    if name not in mangled:
        sys.exit(f"Intent {name} nicht im Binary gefunden")
    actions[name] = {
        "assistantDefinedSchemas": [], "assistantDefinedSchemaTraits": [],
        "authenticationPolicy": 0,
        "availabilityAnnotations": {"LNPlatformNameWildcard": {"introducedVersion": "*"}},
        "effectiveBundleIdentifiers": [],
        "fullyQualifiedTypeName": f"{MODULE}.{name}",
        "identifier": name,
        "isAuthPolExplicit": False, "isDiscoverable": False,
        "mangledTypeName": mangled[name],
        "mangledTypeNameByBundleIdentifier": {}, "mangledTypeNameByBundleIdentifierV2": {},
        "mangledTypeNameV2": mangled[name],
        "openAppWhenRun": False, "outputFlags": 0, "parameters": [],
        "presentationStyle": 0, "requiredCapabilities": [], "supportedModes": 1,
        "systemProtocolMetadata": [], "systemProtocolMetadataV2": [], "systemProtocols": [],
        "title": {"alternatives": [], "key": title},
        "typeSpecificMetadata": [],
        "visibilityMetadata": {"assistantOnly": False, "isDiscoverable": False},
    }

data = {
    "actions": actions, "assistantEntities": [], "assistantIntentNegativePhrases": [],
    "assistantIntents": [], "autoShortcuts": [], "entities": {}, "enums": [],
    "generator": {"name": "xcode-tools", "version": "27A200c"},
    "negativePhrases": [], "queries": {}, "shortcutTileColor": 14, "version": 1,
}
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, "extract.actionsdata"), "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
with open(os.path.join(out_dir, "version.json"), "w") as f:
    json.dump({"toolsVersion": "27A200c", "version": "3.0"}, f, indent=2)
print("App-Intents-Metadaten:", ", ".join(f"{k}={v}" for k, v in mangled.items()))
