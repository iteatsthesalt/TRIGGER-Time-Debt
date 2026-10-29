"""Character specs for tools/art/spritegen.py (Reference Bible §4, §5.2, §5.4).

Palettes are hex strings; proportions are in cell pixels (128 px cell = 2 m, so 114 px ≈ 1.78 m).
Humanoid rigs only: the non-humanoid playables (Cassia-09, Xyloph, Vesper, Pierrot-Glenn, Static,
Omega-Spekkio) get their own rigs in later passes and currently use their painted stand-ins.
"""

U0 = dict(slate="#696C6F", moss="#73814B", royal="#435085", scab="#934A4F", ochre="#B08652", bone="#D3C3AD",
          ink="#2C2C2C", gravel="#565654")

CHARACTERS = {
    # ------------------------------------------------------------------ playables
    "crono": {
        "id": "crono", "group": "characters", "canvas": "u0", "fps": 60, "height": 114, "build": 1.05,
        "hair": "spiky",
        "palette": {
            "skin": "#E2B894", "skin_shadow": "#B58867", "hair": "#B5462F", "hair_shadow": "#7C2C1F",
            "top": U0["royal"], "top_shadow": "#2E3760", "bottom": "#4F4A55", "bottom_shadow": "#34303A",
            "boots": "#5A4634", "boots_shadow": "#3B2D21", "belt": "#6B4A2F", "accent": U0["ochre"],
            "scarf": "#C8763B", "metal": "#B08A4A", "metal_shadow": "#6E5428", "eyes": "#2E4A8A",
            "pauldron": "#7A7C78", "pauldron_shadow": "#4E504C", "moss": U0["moss"], "headband": "#EDE8DA",
        },
        "accessories": ["headband", "scarf", "pauldron", "gauntlet", "stubble", "pouch"],
        "weapon": {"kind": "katana", "length": 44},
    },
    "sera": {
        "id": "sera", "group": "characters", "canvas": "u0", "fps": 60, "height": 100, "build": 0.88, "female": True,
        "hair": "bob", "hover": 4, "heterochromia": "#8B7CFE",
        "palette": {
            "skin": "#E9C4A5", "skin_shadow": "#BF957A", "hair": "#9A4A2E", "hair_shadow": "#66301E",
            "top": "#2F7F86", "top_shadow": "#1E5257", "bottom": "#6F563F", "bottom_shadow": "#4A3828",
            "boots": "#4E3A2A", "boots_shadow": "#32251A", "belt": "#5E4630", "accent": "#D4AF37",
            "scarf": "#A8403E", "metal": "#C9C2B2", "metal_shadow": "#7E7868", "eyes": "#2E4A8A",
            "cape": "#E6DCC3", "cape_shadow": "#B8AD93",
        },
        "accessories": ["scarf", "cape"],
        "weapon": {"kind": "daggers", "length": 18},
    },
    "krona": {
        "id": "krona", "group": "characters", "canvas": "u1", "fps": 24, "height": 112, "build": 1.0, "female": True,
        "hair": "warknot",
        "palette": {
            "skin": "#E8DDCB", "skin_shadow": "#8E8880", "hair": "#2A2724", "hair_shadow": "#141412",
            "top": "#4C4B49", "top_shadow": "#262524", "bottom": "#2E2C2A", "bottom_shadow": "#161514",
            "boots": "#D9CFBE", "boots_shadow": "#8E8880", "belt": "#BE5342", "accent": "#143CA2",
            "metal": "#B8B4AC", "metal_shadow": "#5B5955", "eyes": "#1A1A1A",
            "pauldron": "#6B5E57", "pauldron_shadow": "#3A322E", "moss": "#BE5342", "cape": "#3B3936", "cape_shadow": "#1C1B19",
        },
        "snap_palette": ["#141412", "#4C4B49", "#FBFBF9", "#143CA2", "#BE5342", "#8E8880", "#D9CFBE", "#2A2724", "#6B5E57"],
        "accessories": ["pauldron", "cape", "pouch"],
        "weapon": {"kind": "nodachi", "length": 56},
    },
    # ------------------------------------------------------------------ supporting cast / NPCs
    "marle": {
        "id": "marle", "group": "npcs", "canvas": "u0", "fps": 60, "height": 106, "build": 0.9, "female": True,
        "hair": "ponytail",
        "palette": {
            "skin": "#EBC7A8", "skin_shadow": "#C1977B", "hair": "#E2C25A", "hair_shadow": "#A88B32",
            "top": "#2E4F93", "top_shadow": "#1D3362", "bottom": "#2E4F93", "bottom_shadow": "#1D3362",
            "boots": "#EBC7A8", "boots_shadow": "#C1977B", "belt": "#D4AF37", "accent": "#D4AF37",
            "metal": "#D4AF37", "metal_shadow": "#8A6F1E", "eyes": "#3B6AA8",
        },
        "accessories": [],
        "weapon": {"kind": "crossbow", "length": 20},
    },
    "glenn_marshall": {
        "id": "glenn_marshall", "group": "npcs", "canvas": "u0", "fps": 60, "height": 116, "build": 1.1,
        "hair": "short", "one_armed": True,
        "palette": {
            "skin": "#DDB392", "skin_shadow": "#AD8565", "hair": "#B9B9B4", "hair_shadow": "#7D7D78",
            "top": "#E6E2D6", "top_shadow": "#A9A598", "bottom": "#8A8C8E", "bottom_shadow": "#56585A",
            "boots": "#4A3B2E", "boots_shadow": "#2E241C", "belt": "#D4AF37", "accent": "#D4AF37",
            "metal": "#D4AF37", "metal_shadow": "#8A6F1E", "eyes": "#3A5A3A",
            "cape": "#3F7A4B", "cape_shadow": "#254A2D",
        },
        "accessories": ["cape", "stubble"],
        "weapon": {"kind": "cane", "length": 30},
    },
    "magus": {
        "id": "magus", "group": "npcs", "canvas": "u0", "fps": 60, "height": 120, "build": 0.95,
        "hair": "long",
        "palette": {
            "skin": "#D7CDD9", "skin_shadow": "#A397A8", "hair": "#B8AFD6", "hair_shadow": "#7D73A3",
            "top": "#2A1F45", "top_shadow": "#16102A", "bottom": "#1E1733", "bottom_shadow": "#100C1C",
            "boots": "#26203A", "boots_shadow": "#140F22", "belt": "#5A4A8A", "accent": "#8B7CFE",
            "metal": "#C9C2D6", "metal_shadow": "#6E6880", "eyes": "#B23A3A",
            "cape": "#4B2A6E", "cape_shadow": "#2B1740",
        },
        "accessories": ["cape"],
        "weapon": None,
    },
    "robo_boy": {  # Vaelos as the boy in the Atrium (Act 2); Crono's colours, no gear.
        "id": "vaelos_boy", "group": "npcs", "canvas": "u0", "fps": 60, "height": 80, "build": 0.85, "age": "child",
        "hair": "spiky",
        "palette": {
            "skin": "#EFE6E0", "skin_shadow": "#C4B6B0", "hair": "#C24E33", "hair_shadow": "#86321F",
            "top": "#D9D2C4", "top_shadow": "#A59E90", "bottom": "#6E6A72", "bottom_shadow": "#48454C",
            "boots": "#7C6A58", "boots_shadow": "#4E4236", "belt": "#8A7458", "accent": "#8B7CFE", "eyes": "#8B7CFE",
        },
        "accessories": [],
        "weapon": None,
    },
    # Generic townsfolk for Truce and the Fair (U0). Each is a palette variant of the same rig.
    "villager_m": {
        "id": "villager_m", "group": "npcs", "canvas": "u0", "fps": 60, "height": 110, "build": 1.0, "hair": "short",
        "palette": {"skin": "#E0B48F", "skin_shadow": "#AF8463", "hair": "#5A4030", "hair_shadow": "#36251B",
                    "top": "#7C8A5A", "top_shadow": "#4F5A38", "bottom": "#6B5A48", "bottom_shadow": "#453A2E",
                    "boots": "#4A3B2E", "boots_shadow": "#2E241C", "belt": "#5E4630", "eyes": "#2C2C2C"},
        "accessories": ["pouch"], "weapon": None,
    },
    "villager_f": {
        "id": "villager_f", "group": "npcs", "canvas": "u0", "fps": 60, "height": 104, "build": 0.9, "female": True, "hair": "long",
        "palette": {"skin": "#ECC9AA", "skin_shadow": "#C29A7C", "hair": "#8A5A3A", "hair_shadow": "#573823",
                    "top": "#B46A6A", "top_shadow": "#7A4545", "bottom": "#D3C3AD", "bottom_shadow": "#9C8E7A",
                    "boots": "#5A4634", "boots_shadow": "#3B2D21", "belt": "#6B4A2F", "eyes": "#2C2C2C"},
        "accessories": [], "weapon": None,
    },
    "child": {
        "id": "child", "group": "npcs", "canvas": "u0", "fps": 60, "height": 72, "build": 0.9, "age": "child", "hair": "curly",
        "palette": {"skin": "#EDC7A6", "skin_shadow": "#C29A7C", "hair": "#C8903A", "hair_shadow": "#8A6020",
                    "top": "#5A86B0", "top_shadow": "#3A5A78", "bottom": "#7A5A3A", "bottom_shadow": "#4F3A24",
                    "boots": "#4A3B2E", "boots_shadow": "#2E241C", "belt": "#5E4630", "eyes": "#2C2C2C"},
        "accessories": [], "weapon": None,
    },
    "guard": {
        "id": "guard", "group": "npcs", "canvas": "u0", "fps": 60, "height": 116, "build": 1.1, "hair": "short",
        "palette": {"skin": "#DDB392", "skin_shadow": "#AD8565", "hair": "#4A3A2A", "hair_shadow": "#2C2218",
                    "top": "#8A8C8E", "top_shadow": "#56585A", "bottom": "#2E4F93", "bottom_shadow": "#1D3362",
                    "boots": "#3A3A3A", "boots_shadow": "#1E1E1E", "belt": "#5E4630", "metal": "#A9ABAE", "metal_shadow": "#5E6063",
                    "eyes": "#2C2C2C", "pauldron": "#A9ABAE", "pauldron_shadow": "#5E6063", "moss": "#A9ABAE"},
        "accessories": ["pauldron"], "weapon": {"kind": "cane", "length": 40},
    },
    "elder": {
        "id": "elder", "group": "npcs", "canvas": "u0", "fps": 60, "height": 100, "build": 0.95, "hair": "none",
        "palette": {"skin": "#E6C2A2", "skin_shadow": "#B8947A", "hair": "#D8D8D0", "hair_shadow": "#A0A098",
                    "top": "#6A5A7A", "top_shadow": "#433850", "bottom": "#4F4A55", "bottom_shadow": "#34303A",
                    "boots": "#4A3B2E", "boots_shadow": "#2E241C", "belt": "#5E4630", "eyes": "#2C2C2C"},
        "accessories": ["stubble"], "weapon": {"kind": "cane", "length": 32},
    },
    "merchant": {
        "id": "merchant", "group": "npcs", "canvas": "u0", "fps": 60, "height": 108, "build": 1.15, "hair": "hood",
        "palette": {"skin": "#DDB392", "skin_shadow": "#AD8565", "hair": "#8A3A3A", "hair_shadow": "#5A2222",
                    "top": "#B08652", "top_shadow": "#75582F", "bottom": "#4F4A55", "bottom_shadow": "#34303A",
                    "boots": "#4A3B2E", "boots_shadow": "#2E241C", "belt": "#2C2C2C", "eyes": "#2C2C2C"},
        "accessories": ["pouch"], "weapon": None,
    },
    # U1 townsfolk (sumi-e canvas)
    "ashen_villager": {
        "id": "ashen_villager", "group": "npcs", "canvas": "u1", "fps": 24, "height": 108, "build": 1.0, "hair": "short",
        "palette": {"skin": "#E8DDCB", "skin_shadow": "#8E8880", "hair": "#2A2724", "hair_shadow": "#141412",
                    "top": "#8E8880", "top_shadow": "#4C4B49", "bottom": "#4C4B49", "bottom_shadow": "#262524",
                    "boots": "#D9CFBE", "boots_shadow": "#8E8880", "belt": "#BE5342", "eyes": "#141412"},
        "snap_palette": ["#141412", "#4C4B49", "#FBFBF9", "#BE5342", "#8E8880", "#D9CFBE", "#2A2724", "#E8DDCB"],
        "accessories": [], "weapon": None,
    },
    "ashen_soldier": {
        "id": "ashen_soldier", "group": "npcs", "canvas": "u1", "fps": 24, "height": 114, "build": 1.1, "hair": "warknot",
        "palette": {"skin": "#E8DDCB", "skin_shadow": "#8E8880", "hair": "#141412", "hair_shadow": "#141412",
                    "top": "#262524", "top_shadow": "#141412", "bottom": "#4C4B49", "bottom_shadow": "#262524",
                    "boots": "#D9CFBE", "boots_shadow": "#8E8880", "belt": "#BE5342", "accent": "#BE5342",
                    "metal": "#B8B4AC", "metal_shadow": "#5B5955", "eyes": "#141412",
                    "pauldron": "#4C4B49", "pauldron_shadow": "#262524", "moss": "#BE5342"},
        "snap_palette": ["#141412", "#4C4B49", "#FBFBF9", "#BE5342", "#8E8880", "#D9CFBE", "#262524", "#E8DDCB", "#B8B4AC"],
        "accessories": ["pauldron"], "weapon": {"kind": "katana", "length": 40},
    },
}
