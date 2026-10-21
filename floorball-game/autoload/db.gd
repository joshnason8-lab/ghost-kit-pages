extends Node
## The teams, their squads and kits, and the venues. National teams, as plain country names with their flags, and ten
## invented clubs for the club season (CLUBS): no real players, clubs, leagues or competitions (store/PLAY_STORE.md,
## "Names"). Ratings follow the world ranking order of the men's and women's championships (docs/LANGUAGES.md,
## "Markets").

## id: [rating men, rating women, home jersey, home shorts, away jersey, away shorts, trim]
const TEAMS := {
	"SWE": [96, 97, "f7c600", "1c4fa3", "1c4fa3", "1c4fa3", "f7c600"],
	"FIN": [95, 93, "ffffff", "123c8c", "123c8c", "123c8c", "ffffff"],
	"SUI": [90, 92, "d52b1e", "d52b1e", "ffffff", "ffffff", "ffffff"],
	"CZE": [89, 90, "ffffff", "d7141a", "11457e", "11457e", "d7141a"],
	"SVK": [80, 82, "ffffff", "0b4ea2", "0b4ea2", "0b4ea2", "ee1c25"],
	"LAT": [79, 80, "9e3039", "9e3039", "ffffff", "ffffff", "ffffff"],
	"NOR": [78, 81, "ba0c2f", "00205b", "ffffff", "ffffff", "00205b"],
	"DEN": [77, 78, "c8102e", "ffffff", "ffffff", "c8102e", "ffffff"],
	"GER": [76, 76, "ffffff", "1a1a1a", "1a1a1a", "1a1a1a", "dd0000"],
	"EST": [72, 70, "0072ce", "1a1a1a", "ffffff", "ffffff", "1a1a1a"],
	"POL": [70, 79, "ffffff", "dc143c", "dc143c", "dc143c", "ffffff"],
	"AUT": [67, 66, "ed2939", "ffffff", "ffffff", "ed2939", "ffffff"],
	"HUN": [64, 68, "ce2939", "ffffff", "477050", "477050", "ffffff"],
	"ITA": [62, 60, "0064aa", "ffffff", "ffffff", "0064aa", "009246"],
	"THA": [61, 64, "241d4f", "241d4f", "ffffff", "a51931", "a51931"],
	"JPN": [60, 67, "bc002d", "ffffff", "ffffff", "1a2a6c", "bc002d"],
	"CAN": [59, 61, "d80621", "ffffff", "ffffff", "d80621", "d80621"],
	"USA": [58, 62, "0a3161", "ffffff", "ffffff", "b31942", "b31942"],
	"SGP": [57, 63, "ef3340", "ffffff", "ffffff", "ef3340", "ef3340"],
	"AUS": [55, 58, "00843d", "ffcd00", "ffcd00", "00843d", "00843d"],
	"PHI": [54, 56, "0038a8", "ffffff", "ffffff", "ce1126", "fcd116"],
	"NED": [53, 55, "ff7f00", "ffffff", "ffffff", "21468b", "21468b"],
}

## The club season's ten clubs: invented nicknames (a colour or material and an animal), no town, no real club,
## league or sponsor; proper names, the same in every language. Each has a three-letter code for the scoreboard (none
## a country's), two kit colours, a rating like a domestic league's (below the top national teams) and the country
## whose names its squad is drawn from. No flag: a crest, a shield in the club's colours with its code (ui/crest.gd).
## id: [name, rating men, rating women, home jersey, home shorts, away jersey, away shorts, trim, country]
const CLUBS := {
	"FOX": ["Copper Foxes", 84, 82, "b8652e", "2b1d16", "ffffff", "b8652e", "2b1d16", "SWE"],
	"WLV": ["Glacier Wolves", 83, 84, "8cc8e8", "14315c", "14315c", "14315c", "8cc8e8", "FIN"],
	"LYX": ["Thunder Lynx", 82, 79, "f2c230", "1a1a1a", "1a1a1a", "1a1a1a", "f2c230", "CZE"],
	"OWL": ["Midnight Owls", 81, 83, "1b2440", "1b2440", "ffffff", "ffffff", "e0b04a", "SUI"],
	"MSE": ["Granite Moose", 80, 78, "6b7078", "2a2d33", "ffffff", "6b7078", "e8e8e8", "FIN"],
	"RVN": ["Ember Ravens", 79, 80, "c2361f", "1a1a1a", "ffffff", "1a1a1a", "f08a24", "SWE"],
	"SEL": ["Silver Seals", 78, 77, "c0c6cc", "1d2b4f", "1d2b4f", "1d2b4f", "c0c6cc", "NOR"],
	"BDG": ["Iron Badgers", 77, 75, "3a3d42", "3a3d42", "ffffff", "ffffff", "d9d9d9", "CZE"],
	"HWK": ["Amber Hawks", 75, 81, "e89a1c", "3b2410", "3b2410", "3b2410", "e89a1c", "SUI"],
	"OTR": ["Polar Otters", 74, 74, "f4f7fa", "3d7fb8", "3d7fb8", "3d7fb8", "f4f7fa", "SWE"],
}

## Venues: the local sports hall (a few hundred on one side), a city arena (stands all round), a school gym.
const VENUES := {
	"hall": {"crowd": 380, "stands": "side", "walls": "d8c49a", "light": 1.0},
	"arena": {"crowd": 5200, "stands": "bowl", "walls": "22262d", "light": 1.15},
	"school": {"crowd": 60, "stands": "none", "walls": "c9d3db", "light": 0.92},
}

## Invented, ordinary names for each country's squads (no real players'): given names (men, women) and family names.
const NAMES := {
	"SWE": [["Erik", "Johan", "Oskar", "Linus", "Viktor", "Albin", "Emil", "Gustav", "Hampus", "Isak", "Jonas", "Kalle", "Lucas", "Melker", "Nils", "Olle", "Rasmus", "Simon", "Theo", "Vilhelm"],
		["Ebba", "Elin", "Frida", "Hanna", "Ida", "Julia", "Klara", "Linnea", "Maja", "Moa", "Saga", "Sara", "Tilda", "Tove", "Wilma", "Alva", "Amanda", "Elsa", "Felicia", "Agnes"],
		["Andersson", "Berg", "Dahl", "Ekström", "Forsberg", "Gustafsson", "Holm", "Isaksson", "Jansson", "Karlsson", "Lindqvist", "Lund", "Magnusson", "Nyström", "Olsson", "Persson", "Sjöberg", "Strand", "Wallin", "Åberg"]],
	"FIN": [["Aleksi", "Eetu", "Joni", "Juho", "Kalle", "Lauri", "Mikko", "Niko", "Otto", "Pekka", "Rasmus", "Sami", "Teemu", "Tuomas", "Valtteri", "Veeti", "Ville", "Jere", "Onni", "Arttu"],
		["Aino", "Anni", "Eveliina", "Emma", "Iida", "Jenna", "Katja", "Laura", "Milla", "Noora", "Oona", "Pinja", "Riikka", "Salla", "Sanni", "Tiia", "Venla", "Veera", "Elli", "Ronja"],
		["Heikkinen", "Hämäläinen", "Järvinen", "Kallio", "Koskinen", "Laine", "Lehtonen", "Mäkinen", "Nieminen", "Niemi", "Ojala", "Peltonen", "Rantanen", "Salminen", "Saarinen", "Toivonen", "Turunen", "Virtanen", "Väisänen", "Kinnunen"]],
	"SUI": [["Luca", "Noah", "Nico", "Jonas", "Lars", "Fabian", "Marco", "Reto", "Simon", "Pascal", "Yannick", "Joël", "Lukas", "Matthias", "Silvan", "Raphael", "Dario", "Cédric", "Andrin", "Gian"],
		["Lea", "Laura", "Nina", "Sarah", "Jana", "Céline", "Anja", "Seraina", "Flurina", "Michelle", "Corin", "Ladina", "Tanja", "Lara", "Noemi", "Chiara", "Svenja", "Alina", "Mirjam", "Selina"],
		["Bühler", "Frei", "Gerber", "Hofer", "Keller", "Kunz", "Meier", "Moser", "Müller", "Schmid", "Steiner", "Suter", "Wenger", "Zürcher", "Brunner", "Baumann", "Graf", "Huber", "Bachmann", "Fischer"]],
	"CZE": [["Jakub", "Jan", "Tomáš", "Ondřej", "Matěj", "Filip", "Lukáš", "Vojtěch", "Adam", "David", "Martin", "Petr", "Daniel", "Michal", "Šimon", "Dominik", "Marek", "Radek", "Vít", "Patrik"],
		["Tereza", "Eliška", "Kateřina", "Barbora", "Anna", "Adéla", "Veronika", "Lucie", "Klára", "Natálie", "Michaela", "Denisa", "Kristýna", "Markéta", "Zuzana", "Simona", "Nikola", "Petra", "Aneta", "Lenka"],
		["Novák", "Svoboda", "Dvořák", "Černý", "Procházka", "Kučera", "Veselý", "Horák", "Němec", "Marek", "Pospíšil", "Hájek", "Král", "Jelínek", "Růžička", "Beneš", "Fiala", "Sedláček", "Zeman", "Kolář"]],
	"SVK": [["Martin", "Peter", "Michal", "Lukáš", "Tomáš", "Jakub", "Matej", "Samuel", "Adam", "Filip", "Marek", "Dávid", "Patrik", "Juraj", "Rastislav", "Šimon", "Erik", "Branislav", "Oliver", "Roman"],
		["Lucia", "Zuzana", "Katarína", "Michaela", "Simona", "Veronika", "Natália", "Barbora", "Kristína", "Nikola", "Petra", "Lenka", "Ivana", "Monika", "Alžbeta", "Dominika", "Tamara", "Jana", "Lívia", "Ema"],
		["Horváth", "Kováč", "Varga", "Tóth", "Nagy", "Baláž", "Molnár", "Szabó", "Lukáč", "Kollár", "Šimko", "Oravec", "Hudák", "Mikuš", "Kráľ", "Polák", "Vlček", "Švec", "Novotný", "Rusnák"]],
	"LAT": [["Jānis", "Andris", "Kārlis", "Mārtiņš", "Edgars", "Roberts", "Artūrs", "Kristaps", "Rihards", "Toms", "Raivis", "Gatis", "Ainārs", "Dāvis", "Emīls", "Niks", "Ralfs", "Uģis", "Valters", "Oskars"],
		["Anna", "Laura", "Elīna", "Līga", "Kristīne", "Ilze", "Santa", "Evija", "Agnese", "Madara", "Zane", "Sanita", "Dace", "Alise", "Katrīna", "Marta", "Linda", "Paula", "Rūta", "Sintija"],
		["Bērziņš", "Kalniņš", "Ozoliņš", "Liepiņš", "Krūmiņš", "Balodis", "Zariņš", "Pētersons", "Vītols", "Kļaviņš", "Lācis", "Jansons", "Eglītis", "Siliņš", "Strazdiņš", "Vilks", "Ābols", "Briedis", "Kārkliņš", "Lapiņš"]],
	"NOR": [["Ole", "Lars", "Henrik", "Magnus", "Sander", "Jonas", "Markus", "Mathias", "Kristian", "Even", "Sindre", "Håkon", "Eirik", "Vegard", "Tobias", "Martin", "Aksel", "Fredrik", "Andreas", "Stian"],
		["Ingrid", "Ida", "Nora", "Thea", "Emma", "Sofie", "Maren", "Silje", "Marte", "Hedda", "Tuva", "Kaja", "Mari", "Ane", "Live", "Oda", "Synne", "Vilde", "Frida", "Iselin"],
		["Hansen", "Johansen", "Olsen", "Larsen", "Andersen", "Pedersen", "Nilsen", "Kristiansen", "Jensen", "Karlsen", "Haugen", "Berg", "Eriksen", "Bakken", "Lie", "Moen", "Solberg", "Dahl", "Strand", "Hagen"]],
	"DEN": [["Mads", "Rasmus", "Mikkel", "Frederik", "Jonas", "Emil", "Oliver", "Mathias", "Kasper", "Anders", "Christian", "Søren", "Tobias", "Magnus", "Jeppe", "Nikolaj", "Lasse", "Simon", "Malthe", "Asger"],
		["Sofie", "Ida", "Emma", "Freja", "Laura", "Cecilie", "Mathilde", "Julie", "Signe", "Maja", "Anna", "Karoline", "Line", "Mette", "Nanna", "Josefine", "Clara", "Astrid", "Sara", "Rikke"],
		["Nielsen", "Jensen", "Hansen", "Pedersen", "Andersen", "Christensen", "Larsen", "Sørensen", "Rasmussen", "Jørgensen", "Petersen", "Madsen", "Kristensen", "Olsen", "Thomsen", "Poulsen", "Møller", "Mortensen", "Holm", "Lund"]],
	"GER": [["Lukas", "Jonas", "Felix", "Leon", "Maximilian", "Tim", "Moritz", "Niklas", "Paul", "Jan", "Florian", "Tobias", "Philipp", "Simon", "Johannes", "Fabian", "Julian", "Sebastian", "Kai", "Marvin"],
		["Lena", "Anna", "Laura", "Lea", "Sophie", "Hannah", "Johanna", "Marie", "Julia", "Lisa", "Katharina", "Clara", "Leonie", "Jana", "Carolin", "Franziska", "Nele", "Paula", "Maja", "Svenja"],
		["Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Schulz", "Hoffmann", "Koch", "Richter", "Klein", "Wolf", "Neumann", "Schwarz", "Zimmermann", "Braun", "Krüger", "Hartmann"]],
	"EST": [["Martin", "Rasmus", "Karl", "Markus", "Robin", "Kristjan", "Siim", "Taavi", "Rauno", "Andres", "Mihkel", "Oliver", "Sander", "Kaspar", "Joonas", "Henri", "Tanel", "Priit", "Mattias", "Sten"],
		["Liis", "Kadri", "Triin", "Kristiina", "Laura", "Mari", "Anna", "Grete", "Kertu", "Helena", "Getter", "Merili", "Eliisa", "Hanna", "Kätlin", "Sandra", "Mirjam", "Elisabeth", "Marta", "Johanna"],
		["Tamm", "Saar", "Sepp", "Mägi", "Kask", "Kukk", "Rebane", "Ilves", "Pärn", "Koppel", "Lepik", "Kuusk", "Oja", "Raud", "Luik", "Kaasik", "Vaher", "Lill", "Põder", "Kallas"]],
	"POL": [["Jakub", "Kacper", "Szymon", "Mateusz", "Michał", "Piotr", "Paweł", "Bartosz", "Tomasz", "Kamil", "Łukasz", "Krzysztof", "Dawid", "Wojciech", "Marcin", "Adrian", "Filip", "Maciej", "Damian", "Grzegorz"],
		["Julia", "Zuzanna", "Maja", "Natalia", "Aleksandra", "Wiktoria", "Oliwia", "Karolina", "Magdalena", "Agnieszka", "Katarzyna", "Joanna", "Paulina", "Monika", "Klaudia", "Weronika", "Kinga", "Marta", "Ewa", "Dominika"],
		["Nowak", "Kowalski", "Wiśniewski", "Wójcik", "Kamiński", "Lewandowski", "Zieliński", "Szymański", "Woźniak", "Dąbrowski", "Kozłowski", "Jankowski", "Mazur", "Krawczyk", "Piotrowski", "Grabowski", "Pawłowski", "Michalski", "Król", "Wieczorek"]],
	"AUT": [["Lukas", "Tobias", "David", "Florian", "Jakob", "Simon", "Fabian", "Daniel", "Stefan", "Matthias", "Michael", "Paul", "Elias", "Julian", "Alexander", "Dominik", "Philipp", "Thomas", "Andreas", "Markus"],
		["Anna", "Lena", "Sarah", "Julia", "Laura", "Katharina", "Hannah", "Sophie", "Lisa", "Magdalena", "Elena", "Johanna", "Theresa", "Viktoria", "Nina", "Valentina", "Marlene", "Carina", "Verena", "Eva"],
		["Gruber", "Huber", "Bauer", "Wagner", "Pichler", "Steiner", "Moser", "Mayer", "Hofer", "Leitner", "Berger", "Fuchs", "Eder", "Fischer", "Schmid", "Winkler", "Weber", "Schwarz", "Maier", "Brunner"]],
	"HUN": [["Bence", "Máté", "Levente", "Dávid", "Ádám", "Balázs", "Péter", "Gergő", "Tamás", "Zoltán", "Dániel", "Márk", "Bálint", "Krisztián", "Norbert", "Attila", "Gábor", "Áron", "Barnabás", "Csaba"],
		["Anna", "Hanna", "Réka", "Eszter", "Petra", "Dóra", "Zsófia", "Fanni", "Luca", "Kitti", "Boglárka", "Viktória", "Nóra", "Lili", "Noémi", "Krisztina", "Dorina", "Bianka", "Vivien", "Szandra"],
		["Nagy", "Kovács", "Tóth", "Szabó", "Horváth", "Varga", "Kiss", "Molnár", "Németh", "Farkas", "Balogh", "Papp", "Takács", "Juhász", "Lakatos", "Mészáros", "Oláh", "Simon", "Rácz", "Fekete"]],
	"ITA": [["Luca", "Marco", "Matteo", "Andrea", "Alessandro", "Lorenzo", "Davide", "Simone", "Federico", "Riccardo", "Giacomo", "Stefano", "Nicola", "Paolo", "Tommaso", "Filippo", "Michele", "Gabriele", "Pietro", "Elia"],
		["Giulia", "Chiara", "Francesca", "Sara", "Martina", "Alessia", "Elisa", "Federica", "Valentina", "Silvia", "Laura", "Anna", "Elena", "Giorgia", "Arianna", "Beatrice", "Irene", "Marta", "Sofia", "Camilla"],
		["Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco", "Bruno", "Gallo", "Conti", "De Luca", "Costa", "Giordano", "Mancini", "Rizzo", "Lombardi", "Moretti"]],
	"THA": [["Somchai", "Anan", "Kittisak", "Thanakorn", "Nattapong", "Chaiwat", "Pongsak", "Wichai", "Supachai", "Krit", "Phuwadol", "Tanawat", "Jirayu", "Sarawut", "Teerapat", "Worawit", "Pichit", "Arthit", "Suriya", "Nopadol"],
		["Siriporn", "Nattaya", "Kanokwan", "Pimchanok", "Ratchanee", "Suda", "Waraporn", "Jiraporn", "Kamonwan", "Ploy", "Sasithorn", "Patcharee", "Chutima", "Darunee", "Nanthida", "Orathai", "Benjamas", "Rungnapa", "Thitima", "Malee"],
		["Saetang", "Srisuk", "Wongsa", "Chaiyaphum", "Boonmee", "Thongdee", "Suwan", "Kaewkla", "Phromma", "Inthong", "Rattanakorn", "Sukjai", "Jandee", "Sombat", "Kongkaew", "Siriwat", "Meesuk", "Phanthong", "Chuenchom", "Nakpradit"]],
	"JPN": [["Haruto", "Sota", "Yuto", "Ren", "Riku", "Kaito", "Takumi", "Shota", "Daiki", "Kenta", "Yuki", "Hayato", "Ryota", "Sho", "Kota", "Naoki", "Tatsuya", "Kazuki", "Yusuke", "Taiga"],
		["Yui", "Hina", "Aoi", "Mio", "Sakura", "Yuna", "Rin", "Saki", "Mei", "Nanami", "Misaki", "Haruka", "Ayaka", "Kaho", "Moe", "Riko", "Akari", "Natsuki", "Yuka", "Chihiro"],
		["Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato", "Yoshida", "Yamada", "Sasaki", "Matsumoto", "Inoue", "Kimura", "Hayashi", "Shimizu", "Mori", "Ikeda"]],
	"CAN": [["Liam", "Noah", "Ethan", "Lucas", "Owen", "Nathan", "Logan", "Jacob", "Ryan", "Dylan", "Samuel", "Félix", "Mathis", "Tyler", "Connor", "Evan", "Mason", "Jayden", "Gabriel", "Cole"],
		["Emma", "Olivia", "Charlotte", "Chloé", "Ava", "Léa", "Sophie", "Megan", "Hailey", "Madison", "Rachel", "Brooke", "Kaitlyn", "Jade", "Amélie", "Paige", "Taylor", "Claire", "Emily", "Abby"],
		["Smith", "Tremblay", "Martin", "Roy", "Wilson", "MacDonald", "Gagnon", "Johnson", "Taylor", "Côté", "Campbell", "Anderson", "Leblanc", "Lee", "Brown", "Bouchard", "Gauthier", "Morin", "Fraser", "Stewart"]],
	"USA": [["Jake", "Tyler", "Ryan", "Kyle", "Brandon", "Austin", "Cody", "Zach", "Josh", "Matt", "Nick", "Sean", "Kevin", "Derek", "Trevor", "Chase", "Blake", "Connor", "Logan", "Evan"],
		["Ashley", "Megan", "Lauren", "Kayla", "Brittany", "Morgan", "Taylor", "Rachel", "Hannah", "Emily", "Alexis", "Haley", "Jordan", "Madison", "Sydney", "Abby", "Kelsey", "Paige", "Riley", "Jenna"],
		["Miller", "Davis", "Garcia", "Rodriguez", "Martinez", "Anderson", "Thomas", "Jackson", "White", "Harris", "Clark", "Lewis", "Walker", "Hall", "Young", "Allen", "King", "Wright", "Scott", "Green"]],
	"SGP": [["Wei Jie", "Jun Hao", "Zhi Hao", "Ryan", "Marcus", "Darren", "Jonathan", "Hafiz", "Irfan", "Arjun", "Ming Wei", "Kai Xiang", "Daniel", "Shawn", "Aloysius", "Benjamin", "Rizwan", "Nicholas", "Jia Le", "Bryan"],
		["Hui Min", "Xin Yi", "Jia Hui", "Rachel", "Nur Aisyah", "Priya", "Shu Ting", "Wen Qi", "Vanessa", "Michelle", "Siti", "Charmaine", "Jasmine", "Kai Ling", "Natalie", "Pei Shan", "Sherlyn", "Amanda", "Yi Xuan", "Divya"],
		["Tan", "Lim", "Lee", "Ng", "Ong", "Wong", "Goh", "Chua", "Chan", "Koh", "Teo", "Ang", "Yeo", "Tay", "Ho", "Low", "Rahman", "Kumar", "Ismail", "Sim"]],
	"AUS": [["Jack", "Liam", "Lachlan", "Cooper", "Riley", "Mitchell", "Hamish", "Angus", "Callum", "Tom", "Brodie", "Jai", "Flynn", "Harrison", "Xavier", "Ben", "Josh", "Sam", "Declan", "Toby"],
		["Chloe", "Isla", "Matilda", "Ruby", "Zoe", "Georgia", "Jess", "Sienna", "Tahlia", "Brooke", "Emily", "Grace", "Maddie", "Ella", "Lily", "Kate", "Hayley", "Abbey", "Olivia", "Amelia"],
		["Smith", "Jones", "Williams", "Brown", "Wilson", "Taylor", "Johnson", "White", "Martin", "Anderson", "Thompson", "Nguyen", "Thomas", "Walker", "Harris", "Ryan", "Robinson", "Kelly", "King", "Murphy"]],
	"PHI": [["Juan", "Miguel", "Gabriel", "Carlo", "Paolo", "Rafael", "Jerome", "Marco", "Joshua", "Kenneth", "Angelo", "Christian", "Mark", "John Paul", "Ramon", "Andrei", "Bryan", "Francis", "Kevin", "Lorenzo"],
		["Maria", "Angelica", "Kristine", "Camille", "Patricia", "Andrea", "Bea", "Jasmine", "Nicole", "Erika", "Joanna", "Princess", "Mika", "Trisha", "Bianca", "Danica", "Katrina", "Grace", "Alyssa", "Ella"],
		["Santos", "Reyes", "Cruz", "Bautista", "Ocampo", "Garcia", "Mendoza", "Torres", "Tomas", "Andrada", "Castillo", "Flores", "Villanueva", "Ramos", "Rivera", "Aquino", "Navarro", "Salazar", "Mercado", "Dela Cruz"]],
	"NED": [["Daan", "Sem", "Lucas", "Milan", "Levi", "Luuk", "Bram", "Thijs", "Jesse", "Ruben", "Tim", "Lars", "Stijn", "Joost", "Niels", "Wouter", "Koen", "Jasper", "Sven", "Pim"],
		["Emma", "Julia", "Sophie", "Lotte", "Fleur", "Anne", "Sanne", "Femke", "Lisa", "Eva", "Iris", "Noor", "Roos", "Lieke", "Mila", "Tess", "Isa", "Floor", "Merel", "Esmee"],
		["de Jong", "Jansen", "de Vries", "van den Berg", "van Dijk", "Bakker", "Janssen", "Visser", "Smit", "Meijer", "de Boer", "Mulder", "de Groot", "Bos", "Vos", "Peters", "Hendriks", "van Leeuwen", "Dekker", "Brouwer"]],
}

const SKIN := ["f1c9a5", "e8b48f", "d9a07a", "c68660", "a96c48", "8a5534", "6b3f24"]
const HAIR := ["2a1d14", "4a3220", "6e4b2a", "a0743f", "d6b36e", "e8d29a", "1a1410", "3b2a20"]

var _squads := {}


func team(id: String) -> Dictionary:
	var t: Array = []
	if TEAMS.has(id):
		t = TEAMS[id]
	elif CLUBS.has(id):
		t = (CLUBS[id] as Array).slice(1, 8)
	else:
		return {}
	return {"id": id, "rating_m": t[0], "rating_w": t[1], "home": [Color(t[2]), Color(t[3])], "away": [Color(t[4]), Color(t[5])], "trim": Color(t[6]), "c1": Color(t[2]) if Color(t[2]) != Color.WHITE else Color(t[3])}


func team_ids() -> Array:
	return TEAMS.keys()


func team_name(id: String) -> String:
	if CLUBS.has(id):
		return String(CLUBS[id][0])
	return tr("TEAM_" + id)


func rating(id: String, women := false) -> int:
	if CLUBS.has(id):
		return int(CLUBS[id][2] if women else CLUBS[id][1])
	var t: Array = TEAMS.get(id, [50, 50])
	return int(t[1] if women else t[0])


## The club season's clubs, strongest first.
func club_ids() -> Array:
	return CLUBS.keys()


func is_club(id: String) -> bool:
	return CLUBS.has(id)


## The country a team's players come from: its own for a national team, the club's for a club.
func nation(id: String) -> String:
	return String(CLUBS[id][8]) if CLUBS.has(id) else id


## The kits two teams wear: the home side its home kit; the visitors theirs too unless the jerseys are alike, when
## they change to their second (Rules 205: the teams' clothing must be clearly different).
func kits(home: String, away: String) -> Array:
	var h := team(home)
	var a := team(away)
	var hk: Array = h.home
	var ak: Array = a.home
	if _alike(hk[0], ak[0]):
		ak = a.away
		if _alike(hk[0], ak[0]):
			ak = [Color("1f2933"), Color("1f2933")] if hk[0].get_luminance() > 0.5 else [Color.WHITE, Color.WHITE]
	return [[hk[0], hk[1], h.trim], [ak[0], ak[1], a.trim]]


static func _alike(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.35


## A squad of 20 (Rules 301: at most 20 players): two goalkeepers and three lines of five, each a centre, two
## forwards and two defenders, and a 19th and 20th outfield player in reserve. Players are made from the country's
## name lists (a club's: its country's) and the team's rating, the same for a team every time (seeded by its id).
func squad(id: String, women := false) -> Array:
	var key := "%s|%s" % [id, women]
	if _squads.has(key):
		return _squads[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var nat := nation(id)
	var names: Array = NAMES.get(nat, NAMES["SWE"])
	var given: Array = names[1] if women else names[0]
	var family: Array = names[2]
	var base := rating(id, women)
	var out := []
	var used := {}
	var roles := ["G", "G"]
	for l in 3:
		roles.append_array(["C", "F", "F", "D", "D"])
	roles.append_array(["C", "F", "D"])   # three reserves: a squad of 20 (two goalkeepers, three lines of five)
	var numbers := {}
	for i in roles.size():
		var nm := ""
		for tries in 20:
			nm = "%s %s" % [given[rng.randi() % given.size()], family[rng.randi() % family.size()]]
			if not used.has(nm):
				break
		used[nm] = true
		var num := 0
		while num == 0 or numbers.has(num):
			num = [1, 30, 35, 31][rng.randi() % 4] if roles[i] == "G" else rng.randi_range(2, 99)
		numbers[num] = true
		var line := -1 if i < 2 or i >= 17 else (i - 2) / 5
		var lk: float = [0.0, 4.0, 9.0, 12.0][line + 1] if line >= 0 else 12.0
		var r := clampf(base - lk + rng.randf_range(-6, 6), 30, 99)
		var p := {
			"id": "%s%s%d" % [id, "w" if women else "m", i], "name": nm, "num": num, "role": roles[i], "line": line,
			"speed": clampf(r + rng.randf_range(-10, 10), 25, 99), "shot": clampf(r + rng.randf_range(-12, 12), 25, 99),
			"pass": clampf(r + rng.randf_range(-10, 10), 25, 99), "stick": clampf(r + rng.randf_range(-10, 10), 25, 99),
			"defence": clampf(r + rng.randf_range(-10, 10) + (8.0 if roles[i] == "D" else 0.0), 25, 99),
			"reflex": clampf(r + rng.randf_range(-8, 8), 25, 99) if roles[i] == "G" else 30.0,
			"rating": r, "left": rng.randf() < (0.62 if nat in ["SWE", "FIN", "NOR", "DEN", "EST", "LAT"] else 0.5),
			"skin": _skin_for(nat, rng), "hair": HAIR[rng.randi() % HAIR.size()], "hair_style": rng.randi() % 4,
			"height": rng.randf_range(1.62, 1.76) if women else rng.randf_range(1.72, 1.92), "women": women,
		}
		if nat in ["THA", "JPN", "SGP", "PHI"]:
			p.hair = HAIR[[0, 6, 7][rng.randi() % 3]]
		out.append(p)
	_squads[key] = out
	return out


func _skin_for(id: String, rng: RandomNumberGenerator) -> String:
	match id:
		"THA", "PHI", "SGP":
			return SKIN[rng.randi_range(2, 4)]
		"JPN":
			return SKIN[rng.randi_range(0, 2)]
		"USA", "CAN", "AUS", "NED", "GER", "ITA", "SUI", "AUT":
			return SKIN[rng.randi_range(0, 6) if rng.randf() < 0.25 else rng.randi_range(0, 2)]
	return SKIN[rng.randi_range(0, 1)]


func team_rating(id: String, women := false) -> float:
	return float(rating(id, women))
