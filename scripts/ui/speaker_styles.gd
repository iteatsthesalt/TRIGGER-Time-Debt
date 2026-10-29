## Speaker name tags and colours for the dialogue box (Reference Bible §10.4: speaker colours also carry a name).
class_name SpeakerStyles
extends RefCounted

const STYLES := {
	"crono": {"name": "Crono", "color": Color("#9DB1D9")},
	"sera": {"name": "Sera", "color": Color("#B9AEFF")},
	"marle": {"name": "Marle", "color": Color("#8FB7E6")},
	"krona": {"name": "Krona", "color": Color("#D9655C")},
	"cassia": {"name": "Cassia-09", "color": Color("#E0A858")},
	"lucca": {"name": "Lucca", "color": Color("#D9A5D4")},
	"xyloph": {"name": "Xyloph", "color": Color("#9ED27C")},
	"vesper": {"name": "Vesper", "color": Color("#7FD2CC")},
	"schala": {"name": "Schala", "color": Color("#B7D9F2")},
	"glenn": {"name": "Glenn", "color": Color("#9FCB8C")},
	"pierrot": {"name": "Pierrot-Glenn", "color": Color("#E9D8A6")},
	"static": {"name": "Static", "color": Color("#F2E36B")},
	"omega": {"name": "Omega-Spekkio", "color": Color("#E8C86A")},
	"vaelos": {"name": "Vaelos", "color": Color("#F4F1EC")},
	"robo": {"name": "Robo", "color": Color("#C9A86A")},
	"magus": {"name": "Magus", "color": Color("#B29BD9")},
	"bekkler": {"name": "Bekkler", "color": Color("#E6B0B0")},
	"johnny": {"name": "Johnny", "color": Color("#D79B63")},
	"azar": {"name": "Azar", "color": Color("#C9C091")},
	"kami_ori": {"name": "Kami-Ori", "color": Color("#E6D3A0")},
	"cyrus": {"name": "Cyrus", "color": Color("#A8A29A")},
	"matriarch": {"name": "The Matriarch", "color": Color("#FF6FC2")},
	"narrator": {"name": "", "color": Color("#E1DAC8")},
	"system": {"name": "", "color": Color("#E1DAC8")},
	"synod": {"name": "Synod", "color": Color("#C9C091")},
	"maid": {"name": "Maid", "color": Color("#E1DAC8")},
	"guard": {"name": "Guard", "color": Color("#E1DAC8")},
	"vendor": {"name": "Vendor", "color": Color("#E1DAC8")},
	"child": {"name": "Child", "color": Color("#E1DAC8")},
	"retainer": {"name": "Retainer", "color": Color("#B8A0A0")},
	"ashigaru": {"name": "Ashigaru", "color": Color("#B8A0A0")},
	"townsfolk": {"name": "Townsfolk", "color": Color("#E1DAC8")},
}


static func get_style(who: String) -> Dictionary:
	return STYLES.get(who, {"name": who.capitalize(), "color": Color("#E1DAC8")})
