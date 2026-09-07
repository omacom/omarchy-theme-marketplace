export type ThemeMode = 'dark' | 'light';

export type ThemeColor = 'blue' | 'purple' | 'green' | 'orange' | 'teal' | 'pink' | 'gray';

export interface Theme {
	slug: string;
	name: string;
	repo: string;
	image: string;
	mode: ThemeMode;
	color: ThemeColor;
	author: string;
	likes: number;
	featured?: boolean;
	isNew?: boolean;
}

export const themes: Theme[] = [
	{
		slug: 'aetheria',
		name: 'Aetheria',
		repo: 'https://github.com/JJDizz1L/aetheria',
		image: 'https://omarchy.org/assets/themes/aetheria.webp',
		mode: 'light',
		color: 'blue',
		author: 'JJDizz1L',
		likes: 8,
		featured: true
	},
	{
		slug: 'amberbyte',
		name: 'Amberbyte',
		repo: 'https://github.com/tahfizhabib/omarchy-amberbyte-theme',
		image: 'https://omarchy.org/assets/themes/amberbyte.webp',
		mode: 'dark',
		color: 'purple',
		author: 'tahfizhabib',
		likes: 45
	},
	{
		slug: 'arc-blueberry',
		name: 'Arc Blueberry',
		repo: 'https://github.com/vale-c/omarchy-arc-blueberry',
		image: 'https://omarchy.org/assets/themes/arc-blueberry.webp',
		mode: 'dark',
		color: 'green',
		author: 'vale-c',
		likes: 82
	},
	{
		slug: 'archwave',
		name: 'Archwave',
		repo: 'https://github.com/davidguttman/archwave',
		image: 'https://omarchy.org/assets/themes/archwave.webp',
		mode: 'dark',
		color: 'orange',
		author: 'davidguttman',
		likes: 119,
		isNew: true
	},
	{
		slug: 'ash',
		name: 'Ash',
		repo: 'https://github.com/bjarneo/omarchy-ash-theme',
		image: 'https://omarchy.org/assets/themes/ash.webp',
		mode: 'dark',
		color: 'teal',
		author: 'bjarneo',
		likes: 156
	},
	{
		slug: 'artzen',
		name: 'Artzen',
		repo: 'https://github.com/tahfizhabib/omarchy-artzen-theme',
		image: 'https://omarchy.org/assets/themes/artzen.webp',
		mode: 'dark',
		color: 'pink',
		author: 'tahfizhabib',
		likes: 193
	},
	{
		slug: 'aura',
		name: 'Aura',
		repo: 'https://github.com/bjarneo/omarchy-aura-theme',
		image: 'https://omarchy.org/assets/themes/aura.webp',
		mode: 'dark',
		color: 'gray',
		author: 'bjarneo',
		likes: 230
	},
	{
		slug: 'all-hallow-s-eve',
		name: "All Hallow's Eve",
		repo: 'https://github.com/guilhermetk/omarchy-all-hallows-eve-theme',
		image: 'https://omarchy.org/assets/themes/all-hallow-s-eve.webp',
		mode: 'dark',
		color: 'blue',
		author: 'guilhermetk',
		likes: 267
	},
	{
		slug: 'atelier',
		name: 'Atelier',
		repo: 'https://github.com/atif-1402/omarchy-atelier-theme',
		image: 'https://omarchy.org/assets/themes/atelier.webp',
		mode: 'dark',
		color: 'purple',
		author: 'atif-1402',
		likes: 304
	},
	{
		slug: 'ayaka',
		name: 'Ayaka',
		repo: 'https://github.com/abhijeet-swami/omarchy-ayaka-theme',
		image: 'https://omarchy.org/assets/themes/ayaka.webp',
		mode: 'light',
		color: 'green',
		author: 'abhijeet-swami',
		likes: 341
	},
	{
		slug: 'azure-glow',
		name: 'Azure Glow',
		repo: 'https://github.com/Hydradevx/omarchy-azure-glow-theme',
		image: 'https://omarchy.org/assets/themes/azure-glow.webp',
		mode: 'dark',
		color: 'orange',
		author: 'Hydradevx',
		likes: 378
	},
	{
		slug: 'batman',
		name: 'Batman',
		repo: 'https://github.com/OldJobobo/omarchy-batman-theme',
		image: 'https://omarchy.org/assets/themes/batman.webp',
		mode: 'dark',
		color: 'teal',
		author: 'OldJobobo',
		likes: 415
	},
	{
		slug: 'batou',
		name: 'Batou',
		repo: 'https://github.com/HANCORE-linux/omarchy-batou-theme',
		image: 'https://omarchy.org/assets/themes/batou.webp',
		mode: 'dark',
		color: 'pink',
		author: 'HANCORE-linux',
		likes: 452
	},
	{
		slug: 'bauhaus',
		name: 'Bauhaus',
		repo: 'https://github.com/somerocketeer/omarchy-bauhaus-theme',
		image: 'https://omarchy.org/assets/themes/bauhaus.webp',
		mode: 'dark',
		color: 'gray',
		author: 'somerocketeer',
		likes: 9
	},
	{
		slug: 'biscuit-de-mar-dark',
		name: 'Biscuit de Mar Dark',
		repo: 'https://github.com/OldJobobo/omarchy-biscuit-de-mar-dark-theme',
		image: 'https://omarchy.org/assets/themes/biscuit-de-mar-dark.webp',
		mode: 'dark',
		color: 'blue',
		author: 'OldJobobo',
		likes: 46,
		featured: true
	},
	{
		slug: 'black-arch',
		name: 'Black Arch',
		repo: 'https://github.com/ankur311sudo/black_arch',
		image: 'https://omarchy.org/assets/themes/black-arch.webp',
		mode: 'dark',
		color: 'purple',
		author: 'ankur311sudo',
		likes: 83
	},
	{
		slug: 'black-gold',
		name: 'Black Gold',
		repo: 'https://github.com/HANCORE-linux/omarchy-blackgold-theme',
		image: 'https://omarchy.org/assets/themes/black-gold.webp',
		mode: 'dark',
		color: 'green',
		author: 'HANCORE-linux',
		likes: 120
	},
	{
		slug: 'black-sand',
		name: 'Black Sand',
		repo: 'https://github.com/pkovzz/omarchy-black-sand-theme',
		image: 'https://omarchy.org/assets/themes/black-sand.webp',
		mode: 'dark',
		color: 'orange',
		author: 'pkovzz',
		likes: 157
	},
	{
		slug: 'black-turq',
		name: 'Black Turq',
		repo: 'https://github.com/HANCORE-linux/omarchy-blackturq-theme',
		image: 'https://omarchy.org/assets/themes/black-turq.webp',
		mode: 'light',
		color: 'teal',
		author: 'HANCORE-linux',
		likes: 194
	},
	{
		slug: 'bluedotrb',
		name: 'bluedotrb',
		repo: 'https://github.com/dotsilva/omarchy-bluedotrb-theme',
		image: 'https://omarchy.org/assets/themes/bluedotrb.webp',
		mode: 'dark',
		color: 'pink',
		author: 'dotsilva',
		likes: 231
	},
	{
		slug: 'blue-ridge-dark',
		name: 'Blue Ridge Dark',
		repo: 'https://github.com/hipsterusername/omarchy-blueridge-dark-theme',
		image: 'https://omarchy.org/assets/themes/blue-ridge-dark.webp',
		mode: 'dark',
		color: 'gray',
		author: 'hipsterusername',
		likes: 268
	},
	{
		slug: 'castle-on-a-lake',
		name: 'Castle on a Lake',
		repo: 'https://github.com/shmall03/omarchy-castle-on-a-lake-theme',
		image: 'https://omarchy.org/assets/themes/castle-on-a-lake.webp',
		mode: 'dark',
		color: 'blue',
		author: 'shmall03',
		likes: 305,
		isNew: true
	},
	{
		slug: 'catppuccin-mocha-dark',
		name: 'Catppuccin Mocha Dark',
		repo: 'https://github.com/Luquatic/omarchy-catppuccin-dark',
		image: 'https://omarchy.org/assets/themes/catppuccin-mocha-dark.webp',
		mode: 'dark',
		color: 'purple',
		author: 'Luquatic',
		likes: 342
	},
	{
		slug: 'cincinnati',
		name: 'Cincinnati',
		repo: 'https://github.com/jkwuc89/omarchy-cincinnati-theme',
		image: 'https://omarchy.org/assets/themes/cincinnati.webp',
		mode: 'dark',
		color: 'green',
		author: 'jkwuc89',
		likes: 379
	},
	{
		slug: 'citrus-cynapse',
		name: 'Citrus Cynapse',
		repo: 'https://github.com/Grey-007/citrus-cynapse',
		image: 'https://omarchy.org/assets/themes/citrus-cynapse.webp',
		mode: 'dark',
		color: 'orange',
		author: 'Grey-007',
		likes: 416
	},
	{
		slug: 'city-783',
		name: 'City-783',
		repo: 'https://github.com/OldJobobo/omarchy-city-783-theme',
		image: 'https://omarchy.org/assets/themes/city-783.webp',
		mode: 'dark',
		color: 'teal',
		author: 'OldJobobo',
		likes: 453,
		featured: true
	},
	{
		slug: 'cobalt2',
		name: 'Cobalt2',
		repo: 'https://github.com/hoblin/omarchy-cobalt2-theme',
		image: 'https://omarchy.org/assets/themes/cobalt2.webp',
		mode: 'dark',
		color: 'pink',
		author: 'hoblin',
		likes: 10
	},
	{
		slug: 'coffee',
		name: 'Coffee',
		repo: 'https://github.com/megabyte0x/omarchy-coffee-theme',
		image: 'https://omarchy.org/assets/themes/coffee.webp',
		mode: 'light',
		color: 'gray',
		author: 'megabyte0x',
		likes: 47
	},
	{
		slug: 'coffee-latte',
		name: 'Coffee Latte',
		repo: 'https://github.com/megabyte0x/omarchy-coffee-latte-theme',
		image: 'https://omarchy.org/assets/themes/coffee-latte.webp',
		mode: 'dark',
		color: 'blue',
		author: 'megabyte0x',
		likes: 84
	},
	{
		slug: 'commit',
		name: 'Commit',
		repo: 'https://github.com/c0ze/omarchy-commit-theme',
		image: 'https://omarchy.org/assets/themes/commit.webp',
		mode: 'dark',
		color: 'purple',
		author: 'c0ze',
		likes: 121,
		featured: true
	},
	{
		slug: 'cpunk',
		name: 'CpUnk',
		repo: 'https://github.com/stannorbvb-cmd/cpunk',
		image: 'https://omarchy.org/assets/themes/cpunk.webp',
		mode: 'dark',
		color: 'green',
		author: 'stannorbvb-cmd',
		likes: 158,
		featured: true
	},
	{
		slug: 'crimson-gold',
		name: 'Crimson Gold',
		repo: 'https://github.com/knappkevin/omarchy-crimson-gold-theme',
		image: 'https://omarchy.org/assets/themes/crimson-gold.webp',
		mode: 'dark',
		color: 'orange',
		author: 'knappkevin',
		likes: 195
	},
	{
		slug: 'darcula',
		name: 'Darcula',
		repo: 'https://github.com/noahljungberg/omarchy-darcula-theme',
		image: 'https://omarchy.org/assets/themes/darcula.webp',
		mode: 'dark',
		color: 'teal',
		author: 'noahljungberg',
		likes: 232
	},
	{
		slug: 'demon',
		name: 'Demon',
		repo: 'https://github.com/HANCORE-linux/omarchy-demon-theme',
		image: 'https://omarchy.org/assets/themes/demon.webp',
		mode: 'dark',
		color: 'pink',
		author: 'HANCORE-linux',
		likes: 269
	},
	{
		slug: 'dotrb',
		name: 'Dotrb',
		repo: 'https://github.com/dotsilva/omarchy-dotrb-theme',
		image: 'https://omarchy.org/assets/themes/dotrb.webp',
		mode: 'dark',
		color: 'gray',
		author: 'dotsilva',
		likes: 306
	},
	{
		slug: 'dos-moos',
		name: 'Dos Moos',
		repo: 'https://github.com/HANCORE-linux/omarchy-dos-moos-theme',
		image: 'https://omarchy.org/assets/themes/dos-moos.webp',
		mode: 'dark',
		color: 'blue',
		author: 'HANCORE-linux',
		likes: 343
	},
	{
		slug: 'drac',
		name: 'Drac',
		repo: 'https://github.com/ShehabShaef/omarchy-drac-theme',
		image: 'https://omarchy.org/assets/themes/drac.webp',
		mode: 'light',
		color: 'purple',
		author: 'ShehabShaef',
		likes: 380
	},
	{
		slug: 'dracula',
		name: 'Dracula',
		repo: 'https://github.com/catlee/omarchy-dracula-theme',
		image: 'https://omarchy.org/assets/themes/dracula.webp',
		mode: 'dark',
		color: 'green',
		author: 'catlee',
		likes: 417
	},
	{
		slug: 'eldritch',
		name: 'Eldritch',
		repo: 'https://github.com/eldritch-theme/omarchy',
		image: 'https://omarchy.org/assets/themes/eldritch.webp',
		mode: 'dark',
		color: 'orange',
		author: 'eldritch-theme',
		likes: 454
	},
	{
		slug: 'event-horizon',
		name: 'Event Horizon',
		repo: 'https://github.com/OldJobobo/omarchy-event-horizon-theme',
		image: 'https://omarchy.org/assets/themes/event-horizon.webp',
		mode: 'dark',
		color: 'teal',
		author: 'OldJobobo',
		likes: 11,
		isNew: true
	},
	{
		slug: 'evergarden',
		name: 'Evergarden',
		repo: 'https://github.com/celsobenedetti/omarchy-evergarden',
		image: 'https://omarchy.org/assets/themes/evergarden.webp',
		mode: 'dark',
		color: 'pink',
		author: 'celsobenedetti',
		likes: 48
	},
	{
		slug: 'felix',
		name: 'Felix',
		repo: 'https://github.com/TyRichards/omarchy-felix-theme',
		image: 'https://omarchy.org/assets/themes/felix.webp',
		mode: 'dark',
		color: 'gray',
		author: 'TyRichards',
		likes: 85
	},
	{
		slug: 'fireside',
		name: 'Fireside',
		repo: 'https://github.com/bjarneo/omarchy-fireside-theme',
		image: 'https://omarchy.org/assets/themes/fireside.webp',
		mode: 'dark',
		color: 'blue',
		author: 'bjarneo',
		likes: 122
	},
	{
		slug: 'flat-dracula',
		name: 'Flat Dracula',
		repo: 'https://github.com/OldJobobo/omarchy-flat-dracula-theme',
		image: 'https://omarchy.org/assets/themes/flat-dracula.webp',
		mode: 'dark',
		color: 'purple',
		author: 'OldJobobo',
		likes: 159,
		featured: true
	},
	{
		slug: 'flexoki-dark',
		name: 'Flexoki Dark',
		repo: 'https://github.com/euandeas/omarchy-flexoki-dark-theme',
		image: 'https://omarchy.org/assets/themes/flexoki-dark.webp',
		mode: 'dark',
		color: 'green',
		author: 'euandeas',
		likes: 196
	},
	{
		slug: 'forest-green',
		name: 'Forest Green',
		repo: 'https://github.com/abhijeet-swami/omarchy-forest-green-theme',
		image: 'https://omarchy.org/assets/themes/forest-green.webp',
		mode: 'light',
		color: 'orange',
		author: 'abhijeet-swami',
		likes: 233
	},
	{
		slug: 'frost',
		name: 'Frost',
		repo: 'https://github.com/bjarneo/omarchy-frost-theme',
		image: 'https://omarchy.org/assets/themes/frost.webp',
		mode: 'dark',
		color: 'teal',
		author: 'bjarneo',
		likes: 270
	},
	{
		slug: 'fuchsblau',
		name: 'fuchsblau',
		repo: 'https://github.com/fuchsblau/omarchy-fuchsblau-theme',
		image: 'https://omarchy.org/assets/themes/fuchsblau.webp',
		mode: 'dark',
		color: 'pink',
		author: 'fuchsblau',
		likes: 307
	},
	{
		slug: 'futurism',
		name: 'Futurism',
		repo: 'https://github.com/bjarneo/omarchy-futurism-theme',
		image: 'https://omarchy.org/assets/themes/futurism.webp',
		mode: 'dark',
		color: 'gray',
		author: 'bjarneo',
		likes: 344
	},
	{
		slug: 'futurist',
		name: 'Futurist',
		repo: 'https://github.com/benwillems/omarchy-futurist-theme',
		image: 'https://omarchy.org/assets/themes/futurist.webp',
		mode: 'dark',
		color: 'blue',
		author: 'benwillems',
		likes: 381
	},
	{
		slug: 'gand',
		name: 'Gand',
		repo: 'https://github.com/c0ze/omarchy-gand-theme',
		image: 'https://omarchy.org/assets/themes/gand.webp',
		mode: 'dark',
		color: 'purple',
		author: 'c0ze',
		likes: 418
	},
	{
		slug: 'ghost-pastel',
		name: 'Ghost Pastel',
		repo: 'https://github.com/row-huh/omarchy-ghost-pastel-theme',
		image: 'https://omarchy.org/assets/themes/ghost-pastel.webp',
		mode: 'dark',
		color: 'green',
		author: 'row-huh',
		likes: 455
	},
	{
		slug: 'gold-rush',
		name: 'Gold Rush',
		repo: 'https://github.com/tahayvr/omarchy-gold-rush-theme',
		image: 'https://omarchy.org/assets/themes/gold-rush.webp',
		mode: 'dark',
		color: 'orange',
		author: 'tahayvr',
		likes: 12
	},
	{
		slug: 'golden-brown',
		name: 'Golden Brown',
		repo: 'https://github.com/atif-1402/omarchy-golden-brown-theme',
		image: 'https://omarchy.org/assets/themes/golden-brown.webp',
		mode: 'dark',
		color: 'teal',
		author: 'atif-1402',
		likes: 49
	},
	{
		slug: 'the-greek',
		name: 'The Greek',
		repo: 'https://github.com/HANCORE-linux/omarchy-thegreek-theme',
		image: 'https://omarchy.org/assets/themes/the-greek.webp',
		mode: 'light',
		color: 'pink',
		author: 'HANCORE-linux',
		likes: 86
	},
	{
		slug: 'greek-noir',
		name: 'Greek Noir',
		repo: 'https://github.com/HANCORE-linux/omarchy-greek-noir-theme',
		image: 'https://omarchy.org/assets/themes/greek-noir.webp',
		mode: 'dark',
		color: 'gray',
		author: 'HANCORE-linux',
		likes: 123
	},
	{
		slug: 'green-garden',
		name: 'Green Garden',
		repo: 'https://github.com/kalk-ak/omarchy-green-garden-theme',
		image: 'https://omarchy.org/assets/themes/green-garden.webp',
		mode: 'dark',
		color: 'blue',
		author: 'kalk-ak',
		likes: 160
	},
	{
		slug: 'gruvbox-material',
		name: 'Gruvbox Material',
		repo: 'https://github.com/curbol/omarchy-gruvbox-material',
		image: 'https://omarchy.org/assets/themes/gruvbox-material.webp',
		mode: 'dark',
		color: 'purple',
		author: 'curbol',
		likes: 197,
		isNew: true
	},
	{
		slug: 'gruvu',
		name: 'Gruvu',
		repo: 'https://github.com/ankur311sudo/gruvu',
		image: 'https://omarchy.org/assets/themes/gruvu.webp',
		mode: 'dark',
		color: 'green',
		author: 'ankur311sudo',
		likes: 234,
		featured: true
	},
	{
		slug: 'harbor',
		name: 'Harbor',
		repo: 'https://github.com/HANCORE-linux/omarchy-harbor-theme',
		image: 'https://omarchy.org/assets/themes/harbor.webp',
		mode: 'dark',
		color: 'orange',
		author: 'HANCORE-linux',
		likes: 271
	},
	{
		slug: 'harbor-dark',
		name: 'Harbor Dark',
		repo: 'https://github.com/HANCORE-linux/omarchy-harbordark-theme',
		image: 'https://omarchy.org/assets/themes/harbor-dark.webp',
		mode: 'dark',
		color: 'teal',
		author: 'HANCORE-linux',
		likes: 308
	},
	{
		slug: 'hermarchy',
		name: 'Hermarchy',
		repo: 'https://github.com/archer-clawbot/omarchy-hermarchy-theme',
		image: 'https://omarchy.org/assets/themes/hermarchy.webp',
		mode: 'dark',
		color: 'pink',
		author: 'archer-clawbot',
		likes: 345
	},
	{
		slug: 'hinterlands',
		name: 'Hinterlands',
		repo: 'https://github.com/OldJobobo/omarchy-hinterlands-theme',
		image: 'https://omarchy.org/assets/themes/hinterlands.webp',
		mode: 'dark',
		color: 'gray',
		author: 'OldJobobo',
		likes: 382
	},
	{
		slug: 'infernium',
		name: 'Infernium',
		repo: 'https://github.com/RiO7MAKK3R/omarchy-infernium-dark-theme',
		image: 'https://omarchy.org/assets/themes/infernium.webp',
		mode: 'light',
		color: 'blue',
		author: 'RiO7MAKK3R',
		likes: 419
	},
	{
		slug: 'inky-pinky',
		name: 'Inky Pinky',
		repo: 'https://github.com/HANCORE-linux/omarchy-inkypinky-theme',
		image: 'https://omarchy.org/assets/themes/inky-pinky.webp',
		mode: 'dark',
		color: 'purple',
		author: 'HANCORE-linux',
		likes: 456
	},
	{
		slug: 'japan-night',
		name: 'Japan Night',
		repo: 'https://github.com/devgtv/omarchy-japan-night-theme',
		image: 'https://omarchy.org/assets/themes/japan-night.webp',
		mode: 'dark',
		color: 'green',
		author: 'devgtv',
		likes: 13
	},
	{
		slug: 'lamplight',
		name: 'Lamplight',
		repo: 'https://github.com/thisisgm/omarchy-lamplight-theme',
		image: 'https://omarchy.org/assets/themes/lamplight.webp',
		mode: 'dark',
		color: 'orange',
		author: 'thisisgm',
		likes: 50
	},
	{
		slug: 'lawson-night',
		name: 'Lawson Night',
		repo: 'https://github.com/phuclh/omarchy-lawson-night-theme',
		image: 'https://omarchy.org/assets/themes/lawson-night.webp',
		mode: 'dark',
		color: 'teal',
		author: 'phuclh',
		likes: 87
	},
	{
		slug: 'map-quest',
		name: 'Map Quest',
		repo: 'https://github.com/ItsABigIgloo/omarchy-mapquest-theme',
		image: 'https://omarchy.org/assets/themes/map-quest.webp',
		mode: 'dark',
		color: 'pink',
		author: 'ItsABigIgloo',
		likes: 124
	},
	{
		slug: 'mars',
		name: 'Mars',
		repo: 'https://github.com/steve-lohmeyer/omarchy-mars-theme',
		image: 'https://omarchy.org/assets/themes/mars.webp',
		mode: 'dark',
		color: 'gray',
		author: 'steve-lohmeyer',
		likes: 161
	},
	{
		slug: 'matrix',
		name: 'Matrix',
		repo: 'https://github.com/BVisagie/omarchy-matrix-theme',
		image: 'https://omarchy.org/assets/themes/matrix.webp',
		mode: 'dark',
		color: 'blue',
		author: 'BVisagie',
		likes: 198
	},
	{
		slug: 'mechanoonna',
		name: 'Mechanoonna',
		repo: 'https://github.com/HANCORE-linux/omarchy-mechanoonna-theme',
		image: 'https://omarchy.org/assets/themes/mechanoonna.webp',
		mode: 'dark',
		color: 'purple',
		author: 'HANCORE-linux',
		likes: 235
	},
	{
		slug: 'midnight',
		name: 'Midnight',
		repo: 'https://github.com/JaxonWright/omarchy-midnight-theme',
		image: 'https://omarchy.org/assets/themes/midnight.webp',
		mode: 'light',
		color: 'green',
		author: 'JaxonWright',
		likes: 272
	},
	{
		slug: 'milky-matcha',
		name: 'Milky Matcha',
		repo: 'https://github.com/hipsterusername/omarchy-milkmatcha-light-theme',
		image: 'https://omarchy.org/assets/themes/milky-matcha.webp',
		mode: 'dark',
		color: 'orange',
		author: 'hipsterusername',
		likes: 309,
		featured: true
	},
	{
		slug: 'mini-jcw',
		name: 'Mini Jcw',
		repo: 'https://github.com/davydotcom/omarchy-mini-jcw-theme',
		image: 'https://omarchy.org/assets/themes/mini-jcw.webp',
		mode: 'dark',
		color: 'teal',
		author: 'davydotcom',
		likes: 346
	},
	{
		slug: 'monochrome',
		name: 'Monochrome',
		repo: 'https://github.com/Swarnim114/omarchy-monochrome-theme',
		image: 'https://omarchy.org/assets/themes/monochrome.webp',
		mode: 'dark',
		color: 'pink',
		author: 'Swarnim114',
		likes: 383
	},
	{
		slug: 'monokai',
		name: 'Monokai',
		repo: 'https://github.com/bjarneo/omarchy-monokai-theme',
		image: 'https://omarchy.org/assets/themes/monokai.webp',
		mode: 'dark',
		color: 'gray',
		author: 'bjarneo',
		likes: 420,
		isNew: true
	},
	{
		slug: 'moodpeak',
		name: 'Moodpeak',
		repo: 'https://github.com/HANCORE-linux/omarchy-moodpeak-theme',
		image: 'https://omarchy.org/assets/themes/moodpeak.webp',
		mode: 'dark',
		color: 'blue',
		author: 'HANCORE-linux',
		likes: 457
	},
	{
		slug: 'nagai-poolside',
		name: 'Nagai Poolside',
		repo: 'https://github.com/somerocketeer/omarchy-nagai-poolside-theme',
		image: 'https://omarchy.org/assets/themes/nagai-poolside.webp',
		mode: 'dark',
		color: 'purple',
		author: 'somerocketeer',
		likes: 14
	},
	{
		slug: 'naysayer',
		name: 'Naysayer',
		repo: 'https://github.com/brianblakely/omarchy-naysayer-theme',
		image: 'https://omarchy.org/assets/themes/naysayer.webp',
		mode: 'dark',
		color: 'green',
		author: 'brianblakely',
		likes: 51
	},
	{
		slug: 'neo-sploosh',
		name: 'Neo Sploosh',
		repo: 'https://github.com/monoooki/omarchy-neo-sploosh-theme',
		image: 'https://omarchy.org/assets/themes/neo-sploosh.webp',
		mode: 'dark',
		color: 'orange',
		author: 'monoooki',
		likes: 88
	},
	{
		slug: 'neon-dusk',
		name: 'Neon Dusk',
		repo: 'https://github.com/daniel-felipe/omarchy-neon-dusk-theme',
		image: 'https://omarchy.org/assets/themes/neon-dusk.webp',
		mode: 'light',
		color: 'teal',
		author: 'daniel-felipe',
		likes: 125
	},
	{
		slug: 'neovoid',
		name: 'Neovoid',
		repo: 'https://github.com/RiO7MAKK3R/omarchy-neovoid-theme',
		image: 'https://omarchy.org/assets/themes/neovoid.webp',
		mode: 'dark',
		color: 'pink',
		author: 'RiO7MAKK3R',
		likes: 162
	},
	{
		slug: 'neptune-blue',
		name: 'Neptune Blue',
		repo: 'https://github.com/davydotcom/omarchy-neptune-blue-theme',
		image: 'https://omarchy.org/assets/themes/neptune-blue.webp',
		mode: 'dark',
		color: 'gray',
		author: 'davydotcom',
		likes: 199
	},
	{
		slug: 'nes',
		name: 'NES',
		repo: 'https://github.com/bjarneo/omarchy-nes-theme',
		image: 'https://omarchy.org/assets/themes/nes.webp',
		mode: 'dark',
		color: 'blue',
		author: 'bjarneo',
		likes: 236
	},
	{
		slug: 'noir',
		name: 'Noir',
		repo: 'https://github.com/tahadx/omarchy-noir-theme',
		image: 'https://omarchy.org/assets/themes/noir.webp',
		mode: 'dark',
		color: 'purple',
		author: 'tahadx',
		likes: 273
	},
	{
		slug: 'oligarchy',
		name: 'Oligarchy',
		repo: 'https://github.com/EF-Code/omarchy-oligarchy-theme',
		image: 'https://omarchy.org/assets/themes/oligarchy.webp',
		mode: 'dark',
		color: 'green',
		author: 'EF-Code',
		likes: 310
	},
	{
		slug: 'nujabes',
		name: 'Nujabes',
		repo: 'https://github.com/HalmyLyseas/omarchy-nujabes-theme',
		image: 'https://omarchy.org/assets/themes/nujabes.webp',
		mode: 'dark',
		color: 'orange',
		author: 'HalmyLyseas',
		likes: 347,
		featured: true
	},
	{
		slug: 'omacarchy',
		name: 'Omacarchy',
		repo: 'https://github.com/RiO7MAKK3R/omarchy-omacarchy-theme',
		image: 'https://omarchy.org/assets/themes/omacarchy.webp',
		mode: 'dark',
		color: 'teal',
		author: 'RiO7MAKK3R',
		likes: 384
	},
	{
		slug: 'omaled',
		name: 'OmaLED',
		repo: 'https://github.com/brianblakely/omarchy-omaled-theme',
		image: 'https://omarchy.org/assets/themes/omaled.webp',
		mode: 'dark',
		color: 'pink',
		author: 'brianblakely',
		likes: 421
	},
	{
		slug: 'one-dark',
		name: 'One Dark',
		repo: 'https://github.com/joaopinto15/omarchy-one-dark-theme',
		image: 'https://omarchy.org/assets/themes/one-dark.webp',
		mode: 'light',
		color: 'gray',
		author: 'joaopinto15',
		likes: 458
	},
	{
		slug: 'one-dark-pro',
		name: 'One Dark Pro',
		repo: 'https://github.com/sc0ttman/omarchy-one-dark-pro-theme',
		image: 'https://omarchy.org/assets/themes/one-dark-pro.webp',
		mode: 'dark',
		color: 'blue',
		author: 'sc0ttman',
		likes: 15
	},
	{
		slug: 'oxo-carbon',
		name: 'Oxo Carbon',
		repo: 'https://github.com/HANCORE-linux/omarchy-oxocarbon-theme',
		image: 'https://omarchy.org/assets/themes/oxo-carbon.webp',
		mode: 'dark',
		color: 'purple',
		author: 'HANCORE-linux',
		likes: 52
	},
	{
		slug: 'pagan',
		name: 'Pagan',
		repo: 'https://github.com/c0ze/omarchy-pagan-theme',
		image: 'https://omarchy.org/assets/themes/pagan.webp',
		mode: 'dark',
		color: 'green',
		author: 'c0ze',
		likes: 89
	},
	{
		slug: 'pandora',
		name: 'Pandora',
		repo: 'https://github.com/imbypass/omarchy-pandora-theme',
		image: 'https://omarchy.org/assets/themes/pandora.webp',
		mode: 'dark',
		color: 'orange',
		author: 'imbypass',
		likes: 126,
		isNew: true
	},
	{
		slug: 'periphery',
		name: 'Periphery',
		repo: 'https://github.com/r-bart/omarchy-periphery-theme',
		image: 'https://omarchy.org/assets/themes/periphery.webp',
		mode: 'dark',
		color: 'teal',
		author: 'r-bart',
		likes: 163
	},
	{
		slug: 'pina',
		name: 'Pina',
		repo: 'https://github.com/bjarneo/omarchy-pina-theme',
		image: 'https://omarchy.org/assets/themes/pina.webp',
		mode: 'dark',
		color: 'pink',
		author: 'bjarneo',
		likes: 200
	},
	{
		slug: 'pink-blood',
		name: 'Pink Blood',
		repo: 'https://github.com/ITSZXY/pink-blood-omarchy-theme',
		image: 'https://omarchy.org/assets/themes/pink-blood.webp',
		mode: 'dark',
		color: 'gray',
		author: 'ITSZXY',
		likes: 237
	},
	{
		slug: 'pulsar',
		name: 'Pulsar',
		repo: 'https://github.com/bjarneo/omarchy-pulsar-theme',
		image: 'https://omarchy.org/assets/themes/pulsar.webp',
		mode: 'dark',
		color: 'blue',
		author: 'bjarneo',
		likes: 274
	},
	{
		slug: 'purple-moon',
		name: 'Purple Moon',
		repo: 'https://github.com/Grey-007/purple-moon',
		image: 'https://omarchy.org/assets/themes/purple-moon.webp',
		mode: 'light',
		color: 'purple',
		author: 'Grey-007',
		likes: 311
	},
	{
		slug: 'purplewave',
		name: 'Purplewave',
		repo: 'https://github.com/dotsilva/omarchy-purplewave-theme',
		image: 'https://omarchy.org/assets/themes/purplewave.webp',
		mode: 'dark',
		color: 'green',
		author: 'dotsilva',
		likes: 348
	},
	{
		slug: 'quattrocento-light',
		name: 'Quattrocento Light',
		repo: 'https://github.com/r-bart/omarchy-quattrocento-light-theme',
		image: 'https://omarchy.org/assets/themes/quattrocento-light.webp',
		mode: 'dark',
		color: 'orange',
		author: 'r-bart',
		likes: 385
	},
	{
		slug: 'rainy-night',
		name: 'Rainy Night',
		repo: 'https://github.com/atif-1402/omarchy-rainynight-theme',
		image: 'https://omarchy.org/assets/themes/rainy-night.webp',
		mode: 'dark',
		color: 'teal',
		author: 'atif-1402',
		likes: 422,
		featured: true
	},
	{
		slug: 'red-monarch',
		name: 'Red Monarch',
		repo: 'https://github.com/kamatealif/omarchy-red-monarch-theme',
		image: 'https://omarchy.org/assets/themes/red-monarch.webp',
		mode: 'dark',
		color: 'pink',
		author: 'kamatealif',
		likes: 459
	},
	{
		slug: 'red-pill',
		name: 'Red Pill',
		repo: 'https://github.com/ferlemes/omarchy-red-pill-theme',
		image: 'https://omarchy.org/assets/themes/red-pill.webp',
		mode: 'dark',
		color: 'gray',
		author: 'ferlemes',
		likes: 16
	},
	{
		slug: 'retropc',
		name: 'RetroPC',
		repo: 'https://github.com/rondilley/omarchy-retropc-theme',
		image: 'https://omarchy.org/assets/themes/retropc.webp',
		mode: 'dark',
		color: 'blue',
		author: 'rondilley',
		likes: 53
	},
	{
		slug: 'ristretto-light',
		name: 'Ristretto Light',
		repo: 'https://github.com/brokkoli71/omarchy-ristretto-light-theme',
		image: 'https://omarchy.org/assets/themes/ristretto-light.webp',
		mode: 'dark',
		color: 'purple',
		author: 'brokkoli71',
		likes: 90
	},
	{
		slug: 'robzee84',
		name: 'RobZee84',
		repo: 'https://github.com/robzolkos/omarchy-robzee84-theme',
		image: 'https://omarchy.org/assets/themes/robzee84.webp',
		mode: 'dark',
		color: 'green',
		author: 'robzolkos',
		likes: 127
	},
	{
		slug: 'rose-pine-dark',
		name: 'Rose Pine Dark',
		repo: 'https://github.com/guilhermetk/omarchy-rose-pine-dark',
		image: 'https://omarchy.org/assets/themes/rose-pine-dark.webp',
		mode: 'light',
		color: 'orange',
		author: 'guilhermetk',
		likes: 164
	},
	{
		slug: 'rose-pine-moon',
		name: 'Rose Pine Moon',
		repo: 'https://github.com/Memnoc/omarchy-rose-pine-moon-theme',
		image: 'https://omarchy.org/assets/themes/rose-pine-moon.webp',
		mode: 'dark',
		color: 'teal',
		author: 'Memnoc',
		likes: 201
	},
	{
		slug: 'rose-of-dune',
		name: 'Rose of Dune',
		repo: 'https://github.com/HANCORE-linux/omarchy-roseofdune-theme',
		image: 'https://omarchy.org/assets/themes/rose-of-dune.webp',
		mode: 'dark',
		color: 'pink',
		author: 'HANCORE-linux',
		likes: 238
	},
	{
		slug: 'ryu',
		name: 'Ryu',
		repo: 'https://github.com/HANCORE-linux/omarchy-ryu-theme',
		image: 'https://omarchy.org/assets/themes/ryu.webp',
		mode: 'dark',
		color: 'gray',
		author: 'HANCORE-linux',
		likes: 275
	},
	{
		slug: 'sakura',
		name: 'Sakura',
		repo: 'https://github.com/bjarneo/omarchy-sakura-theme',
		image: 'https://omarchy.org/assets/themes/sakura.webp',
		mode: 'dark',
		color: 'blue',
		author: 'bjarneo',
		likes: 312,
		isNew: true
	},
	{
		slug: 'sakura-mochi',
		name: 'Sakura Mochi',
		repo: 'https://github.com/OldJobobo/omarchy-sakura-mochi-theme',
		image: 'https://omarchy.org/assets/themes/sakura-mochi.webp',
		mode: 'dark',
		color: 'purple',
		author: 'OldJobobo',
		likes: 349
	},
	{
		slug: 'saga',
		name: 'Saga',
		repo: 'https://github.com/HANCORE-linux/omarchy-saga-theme',
		image: 'https://omarchy.org/assets/themes/saga.webp',
		mode: 'dark',
		color: 'green',
		author: 'HANCORE-linux',
		likes: 386
	},
	{
		slug: 'sapphire',
		name: 'Sapphire',
		repo: 'https://github.com/HANCORE-linux/omarchy-sapphire-theme',
		image: 'https://omarchy.org/assets/themes/sapphire.webp',
		mode: 'dark',
		color: 'orange',
		author: 'HANCORE-linux',
		likes: 423
	},
	{
		slug: 'shades-of-jade',
		name: 'Shades of Jade',
		repo: 'https://github.com/HANCORE-linux/omarchy-shadesofjade-theme',
		image: 'https://omarchy.org/assets/themes/shades-of-jade.webp',
		mode: 'dark',
		color: 'teal',
		author: 'HANCORE-linux',
		likes: 460,
		featured: true
	},
	{
		slug: 'space-monkey',
		name: 'Space Monkey',
		repo: 'https://github.com/TyRichards/omarchy-space-monkey-theme/',
		image: 'https://omarchy.org/assets/themes/space-monkey.webp',
		mode: 'light',
		color: 'pink',
		author: 'TyRichards',
		likes: 17
	},
	{
		slug: 'snow',
		name: 'Snow',
		repo: 'https://github.com/bjarneo/omarchy-snow-theme',
		image: 'https://omarchy.org/assets/themes/snow.webp',
		mode: 'dark',
		color: 'gray',
		author: 'bjarneo',
		likes: 54
	},
	{
		slug: 'snow-black',
		name: 'Snow Black',
		repo: 'https://github.com/ankur311sudo/snow_black',
		image: 'https://omarchy.org/assets/themes/snow-black.webp',
		mode: 'dark',
		color: 'blue',
		author: 'ankur311sudo',
		likes: 91
	},
	{
		slug: 'solarized',
		name: 'Solarized',
		repo: 'https://github.com/Gazler/omarchy-solarized-theme',
		image: 'https://omarchy.org/assets/themes/solarized.webp',
		mode: 'dark',
		color: 'purple',
		author: 'Gazler',
		likes: 128
	},
	{
		slug: 'solarized-light',
		name: 'Solarized Light',
		repo: 'https://github.com/dfrico/omarchy-solarized-light-theme',
		image: 'https://omarchy.org/assets/themes/solarized-light.webp',
		mode: 'dark',
		color: 'green',
		author: 'dfrico',
		likes: 165
	},
	{
		slug: 'solarized-osaka',
		name: 'Solarized Osaka',
		repo: 'https://github.com/motorsss/omarchy-solarizedosaka-theme',
		image: 'https://omarchy.org/assets/themes/solarized-osaka.webp',
		mode: 'dark',
		color: 'orange',
		author: 'motorsss',
		likes: 202
	},
	{
		slug: 'starry-night',
		name: 'Starry Night',
		repo: 'https://github.com/juangalt/omarchy-starry-night-theme',
		image: 'https://omarchy.org/assets/themes/starry-night.webp',
		mode: 'dark',
		color: 'teal',
		author: 'juangalt',
		likes: 239
	},
	{
		slug: 'starsend',
		name: 'Starsend',
		repo: 'https://github.com/r-bart/omarchy-starsend-theme',
		image: 'https://omarchy.org/assets/themes/starsend.webp',
		mode: 'dark',
		color: 'pink',
		author: 'r-bart',
		likes: 276
	},
	{
		slug: 'sunset',
		name: 'Sunset',
		repo: 'https://github.com/rondilley/omarchy-sunset-theme',
		image: 'https://omarchy.org/assets/themes/sunset.webp',
		mode: 'dark',
		color: 'gray',
		author: 'rondilley',
		likes: 313
	},
	{
		slug: 'sunset-drive',
		name: 'Sunset Drive',
		repo: 'https://github.com/tahayvr/omarchy-sunset-drive-theme',
		image: 'https://omarchy.org/assets/themes/sunset-drive.webp',
		mode: 'light',
		color: 'blue',
		author: 'tahayvr',
		likes: 350
	},
	{
		slug: 'super-game-bro',
		name: 'Super Game Bro',
		repo: 'https://github.com/TyRichards/omarchy-super-game-bro-theme',
		image: 'https://omarchy.org/assets/themes/super-game-bro.webp',
		mode: 'dark',
		color: 'purple',
		author: 'TyRichards',
		likes: 387
	},
	{
		slug: 'synthwave-84',
		name: "Synthwave '84",
		repo: 'https://github.com/omacom-io/omarchy-synthwave84-theme/',
		image: 'https://omarchy.org/assets/themes/synthwave-84.webp',
		mode: 'dark',
		color: 'green',
		author: 'omacom-io',
		likes: 424
	},
	{
		slug: 'temerald',
		name: 'Temerald',
		repo: 'https://github.com/Ahmad-Mtr/omarchy-temerald-theme',
		image: 'https://omarchy.org/assets/themes/temerald.webp',
		mode: 'dark',
		color: 'orange',
		author: 'Ahmad-Mtr',
		likes: 461
	},
	{
		slug: 'terminus',
		name: 'Terminus',
		repo: 'https://github.com/r-bart/omarchy-terminus-theme',
		image: 'https://omarchy.org/assets/themes/terminus.webp',
		mode: 'dark',
		color: 'teal',
		author: 'r-bart',
		likes: 18,
		isNew: true
	},
	{
		slug: 'tokyo-night-oled',
		name: 'Tokyo Night OLED',
		repo: 'https://github.com/Justin-De-Sio/omarchy-tokyoled-theme',
		image: 'https://omarchy.org/assets/themes/tokyo-night-oled.webp',
		mode: 'dark',
		color: 'pink',
		author: 'Justin-De-Sio',
		likes: 55,
		featured: true
	},
	{
		slug: 'tycho',
		name: 'Tycho',
		repo: 'https://github.com/leonardobetti/omarchy-tycho',
		image: 'https://omarchy.org/assets/themes/tycho.webp',
		mode: 'dark',
		color: 'gray',
		author: 'leonardobetti',
		likes: 92
	},
	{
		slug: 'waffle-cat',
		name: 'Waffle Cat',
		repo: 'https://github.com/OldJobobo/omarchy-waffle-cat-theme',
		image: 'https://omarchy.org/assets/themes/waffle-cat.webp',
		mode: 'dark',
		color: 'blue',
		author: 'OldJobobo',
		likes: 129
	},
	{
		slug: 'waveform-dark',
		name: 'Waveform Dark',
		repo: 'https://github.com/hipsterusername/omarchy-waveform-dark-theme',
		image: 'https://omarchy.org/assets/themes/waveform-dark.webp',
		mode: 'dark',
		color: 'purple',
		author: 'hipsterusername',
		likes: 166
	},
	{
		slug: 'white-gold',
		name: 'White Gold',
		repo: 'https://github.com/HANCORE-linux/omarchy-whitegold-theme',
		image: 'https://omarchy.org/assets/themes/white-gold.webp',
		mode: 'light',
		color: 'green',
		author: 'HANCORE-linux',
		likes: 203
	},
	{
		slug: 'windows-dark-mode',
		name: 'Windows Dark Mode',
		repo: 'https://github.com/oldjobobo/omarchy-windows-dark-mode-theme',
		image: 'https://omarchy.org/assets/themes/windows-dark-mode.webp',
		mode: 'dark',
		color: 'orange',
		author: 'oldjobobo',
		likes: 240
	},
	{
		slug: 'winslow',
		name: 'Winslow',
		repo: 'https://github.com/chipkoziara/omarchy-winslow-theme',
		image: 'https://omarchy.org/assets/themes/winslow.webp',
		mode: 'dark',
		color: 'teal',
		author: 'chipkoziara',
		likes: 277
	},
	{
		slug: 'van-gogh',
		name: 'Van Gogh',
		repo: 'https://github.com/Nirmal314/omarchy-van-gogh-theme',
		image: 'https://omarchy.org/assets/themes/van-gogh.webp',
		mode: 'dark',
		color: 'pink',
		author: 'Nirmal314',
		likes: 314
	},
	{
		slug: 'vault',
		name: 'Vault',
		repo: 'https://github.com/r-bart/omarchy-vault-theme',
		image: 'https://omarchy.org/assets/themes/vault.webp',
		mode: 'dark',
		color: 'gray',
		author: 'r-bart',
		likes: 351
	},
	{
		slug: 'velvet-night',
		name: 'Velvet Night',
		repo: 'https://github.com/HANCORE-linux/omarchy-velvetnight-theme',
		image: 'https://omarchy.org/assets/themes/velvet-night.webp',
		mode: 'dark',
		color: 'blue',
		author: 'HANCORE-linux',
		likes: 388
	},
	{
		slug: 'venice-from-above',
		name: 'Venice from Above',
		repo: 'https://github.com/mattbbia/venice-from-above-omarchy',
		image: 'https://omarchy.org/assets/themes/venice-from-above.webp',
		mode: 'dark',
		color: 'purple',
		author: 'mattbbia',
		likes: 425
	},
	{
		slug: 'vesper',
		name: 'Vesper',
		repo: 'https://github.com/thmoee/omarchy-vesper-theme',
		image: 'https://omarchy.org/assets/themes/vesper.webp',
		mode: 'dark',
		color: 'green',
		author: 'thmoee',
		likes: 462
	},
	{
		slug: 'vhs-80',
		name: 'VHS 80',
		repo: 'https://github.com/tahayvr/omarchy-vhs80-theme',
		image: 'https://omarchy.org/assets/themes/vhs-80.webp',
		mode: 'dark',
		color: 'orange',
		author: 'tahayvr',
		likes: 19
	},
	{
		slug: 'void',
		name: 'Void',
		repo: 'https://github.com/vyrx-dev/omarchy-void-theme',
		image: 'https://omarchy.org/assets/themes/void.webp',
		mode: 'light',
		color: 'teal',
		author: 'vyrx-dev',
		likes: 56
	},
	{
		slug: 'vulkanite',
		name: 'Vulkanite',
		repo: 'https://github.com/kyerpotts/omarchy-vulkanite-theme',
		image: 'https://omarchy.org/assets/themes/vulkanite.webp',
		mode: 'dark',
		color: 'pink',
		author: 'kyerpotts',
		likes: 93
	}
];
