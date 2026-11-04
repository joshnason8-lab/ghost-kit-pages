extends Node
## Teams, squads and venues. Countries and states are named as places; no real club, league, competition or federation
## is named, and every player is invented (names drawn from each region's common given names and family names, never
## a real player's: NAME_BLOCK). Ratings come from the 2025 world championship and the 2026 national championships
## (docs/RULES.md, "Teams"). Squads are made from each team's id, so they are the same on every phone.

## id, name key (a place), flag (Flags), rating men, rating women, kit [shirt, shorts, trim], name pool
const NATIONS := [
	["IND", "C_IND", "IND", 96, 98, ["1f5fbf", "f7f2e8", "ff9933"], "in"],
	["NEP", "C_NEP", "NEP", 86, 84, ["c8102e", "0b2a6b", "f7f2e8"], "np"],
	["RSA", "C_RSA", "RSA", 78, 76, ["0b7a3b", "ffb612", "f7f2e8"], "za"],
	["SRI", "C_SRI", "SRI", 72, 66, ["0b2a6b", "f2b705", "8d153a"], "lk"],
	["BAN", "C_BAN", "BAN", 70, 68, ["006a4e", "f42a41", "f7f2e8"], "bd"],
	["IRN", "C_IRN", "IRN", 66, 64, ["f7f2e8", "239f40", "da0000"], "ir"],
	["ENG", "C_ENG", "ENG", 64, 58, ["f7f2e8", "1b2a5c", "ce1124"], "en"],
	["KEN", "C_KEN", "KEN", 60, 60, ["bb0000", "141414", "006600"], "ke"],
	["UGA", "C_UGA", "UGA", 58, 62, ["fcdc04", "141414", "d90000"], "ke"],
	["MAS", "C_MAS", "MAS", 56, 52, ["010066", "cc0001", "ffcc00"], "my"],
	["GHA", "C_GHA", "GHA", 55, 50, ["006b3f", "fcd116", "ce1126"], "ke"],
	["KOR", "C_KOR", "KOR", 52, 54, ["f7f2e8", "0047a0", "cd2e3a"], "kr"],
	["BHU", "C_BHU", "BHU", 50, 46, ["ff8a1f", "ffd520", "8d1b1b"], "bt"],
	["AUS", "C_AUS", "AUS", 50, 52, ["00843d", "ffcd00", "012169"], "en"],
	["USA", "C_USA", "USA", 50, 48, ["0a3161", "f7f2e8", "b31942"], "en"],
	["INA", "C_INA", "INA", 49, 50, ["ce1126", "f7f2e8", "141414"], "my"],
	["NZL", "C_NZL", "NZL", 48, 50, ["141414", "f7f2e8", "c8102e"], "en"],
	["POL", "C_POL", "POL", 46, 50, ["dc143c", "f7f2e8", "141414"], "eu"],
	["GER", "C_GER", "GER", 46, 44, ["141414", "dd0000", "ffce00"], "eu"],
	["BRA", "C_BRA", "BRA", 45, 44, ["ffdf00", "002776", "009c3b"], "sa"],
	["NED", "C_NED", "NED", 44, 46, ["ff6c00", "1e3a8a", "f7f2e8"], "eu"],
	["ARG", "C_ARG", "ARG", 44, 42, ["6cace4", "141414", "f7f2e8"], "sa"],
	["PER", "C_PER", "PER", 42, 44, ["d91023", "f7f2e8", "141414"], "sa"],
	["JPN", "C_JPN", "JPN", 40, 42, ["f7f2e8", "1b2a5c", "bc002d"], "jp"],
]

## Indian states and union territories, as at a national championship: the place's name and an invented nickname.
const STATES := [
	["MAH", "S_MAH", 92, 97, ["ff8a1f", "7a1f1f", "f7f2e8"], "mr"],
	["ODI", "S_ODI", 86, 91, ["1c7c54", "f2c14e", "f7f2e8"], "or"],
	["KAR", "S_KAR", 87, 84, ["d7263d", "f2c14e", "f7f2e8"], "kn"],
	["KER", "S_KER", 80, 78, ["f7f2e8", "1c7c54", "d4a017"], "ml"],
	["TEL", "S_TEL", 78, 74, ["e4007c", "1b2a5c", "f7f2e8"], "te"],
	["DEL", "S_DEL", 76, 77, ["1b2a5c", "f7f2e8", "e63946"], "hi"],
	["APR", "S_APR", 74, 70, ["0077b6", "f7f2e8", "ffb703"], "te"],
	["WBE", "S_WBE", 74, 75, ["f7f2e8", "c1121f", "003049"], "bn"],
	["GUJ", "S_GUJ", 72, 72, ["ff7f11", "1b2a5c", "f7f2e8"], "gu"],
	["TNA", "S_TNA", 72, 70, ["b5179e", "f7f2e8", "ffb703"], "ta"],
	["MPR", "S_MPR", 70, 71, ["2b9348", "f7f2e8", "ffb703"], "hi"],
	["RAJ", "S_RAJ", 68, 66, ["f9c74f", "9d0208", "f7f2e8"], "hi"],
	["HAR", "S_HAR", 68, 64, ["43aa8b", "141414", "f7f2e8"], "hi"],
	["UPR", "S_UPR", 67, 63, ["3a0ca3", "f7f2e8", "ff9f1c"], "hi"],
	["PUN", "S_PUN", 64, 60, ["ffba08", "1b2a5c", "f7f2e8"], "pa"],
	["CHH", "S_CHH", 63, 62, ["2d6a4f", "f2c14e", "f7f2e8"], "hi"],
	["ASM", "S_ASM", 58, 57, ["c1121f", "f7f2e8", "1b4332"], "as"],
	["GOA", "S_GOA", 58, 56, ["0096c7", "f7f2e8", "f77f00"], "mr"],
]

## The league's city sides: invented, each named for its city with a made-up nickname (none is a real franchise's).
## id, name key, rating men, rating women, kit, name pool. Squads mix the city's region with players from all over.
const CLUBS := [
	["MUM", "L_MUM", 86, 88, ["1f4e8c", "f2c14e", "f7f2e8"], "mr"],
	["PNE", "L_PNE", 84, 85, ["7b2cbf", "f7f2e8", "ffb703"], "mr"],
	["BBS", "L_BBS", 85, 86, ["e85d04", "1b2a5c", "f7f2e8"], "or"],
	["BLR", "L_BLR", 83, 82, ["c1121f", "141414", "f2c14e"], "kn"],
	["HYD", "L_HYD", 80, 78, ["2b9348", "f7f2e8", "ff9f1c"], "te"],
	["CHE", "L_CHE", 79, 77, ["0096c7", "f2c14e", "f7f2e8"], "ta"],
	["KOL", "L_KOL", 77, 79, ["9d0208", "f2c14e", "f7f2e8"], "bn"],
	["AHM", "L_AHM", 78, 76, ["f9c74f", "1b2a5c", "f7f2e8"], "gu"],
]

## Venues: id, name key, surface ("mud" or "mat"), the time of day, the kind of crowd. All invented places.
const VENUES := [
	["maidan", "V_MAIDAN", "mud", "dusk", "village"],
	["school", "V_SCHOOL", "mud", "day", "school"],
	["arena", "V_ARENA", "mat", "indoor", "arena"],
	["floodlit", "V_FLOODLIT", "mud", "night", "stadium"],
]

## Given names (men, women) and family names by region.
const NAMES := {
	"mr": [["Omkar", "Sagar", "Tushar", "Nikhil", "Ganesh", "Rohan", "Sanket", "Vishal", "Akash", "Swapnil", "Prathamesh", "Kunal", "Mayur", "Yogesh", "Amol"],
		["Snehal", "Pooja", "Komal", "Rutuja", "Sayali", "Prajakta", "Shital", "Manasi", "Vaishnavi", "Gauri", "Ankita", "Pallavi", "Rupali", "Kajal", "Tejal"],
		["Jadhav", "Patil", "Pawar", "Kadam", "Shinde", "More", "Gaikwad", "Chavan", "Salunkhe", "Kale", "Mane", "Bhosale", "Deshmukh", "Sawant", "Thorat"]],
	"or": [["Debasis", "Sanjay", "Pradeep", "Bikash", "Manas", "Subhendu", "Ranjan", "Sibaram", "Tapan", "Ashis", "Jagannath", "Prakash", "Dillip", "Satya", "Biswajit"],
		["Subhashree", "Lipsa", "Madhusmita", "Pragyan", "Sasmita", "Rashmita", "Jyotsna", "Mamata", "Smruti", "Ipsita", "Sonali", "Bhagyashree", "Anjali", "Sradhanjali", "Puja"],
		["Behera", "Nayak", "Sahoo", "Pradhan", "Mohanty", "Swain", "Das", "Rout", "Barik", "Sethi", "Jena", "Mallick", "Panda", "Biswal", "Samal"]],
	"kn": [["Manjunath", "Kiran", "Santosh", "Prajwal", "Darshan", "Vinay", "Harish", "Naveen", "Chetan", "Abhishek", "Mahesh", "Shivu", "Pavan", "Raghu", "Yashwanth"],
		["Kavya", "Spoorthi", "Rakshitha", "Bhavya", "Chaitra", "Ananya", "Deepika", "Sahana", "Pallavi", "Shruthi", "Meghana", "Nandini", "Ashwini", "Roopa", "Divya"],
		["Gowda", "Shetty", "Naik", "Hegde", "Patil", "Kulkarni", "Reddy", "Rao", "Bhat", "Kumar", "Murthy", "Hiremath", "Angadi", "Desai", "Pujari"]],
	"ml": [["Arun", "Vishnu", "Akhil", "Midhun", "Jithin", "Sreejith", "Anoop", "Rahul", "Nithin", "Abhijith", "Sarath", "Vipin", "Amal", "Libin", "Sanju"],
		["Anjana", "Aswathy", "Gopika", "Sreelakshmi", "Neethu", "Athira", "Divya", "Reshma", "Arya", "Anagha", "Keerthana", "Lekshmi", "Sandra", "Nimisha", "Haritha"],
		["Nair", "Menon", "Pillai", "Kurup", "Varghese", "Thomas", "Joseph", "Mathew", "Krishnan", "Raj", "Babu", "Kumar", "Mohan", "Das", "Jose"]],
	"te": [["Srinivas", "Venkatesh", "Sai", "Ravi", "Naresh", "Ramesh", "Charan", "Mahesh", "Teja", "Prasad", "Suresh", "Karthik", "Nagaraju", "Anil", "Vamsi"],
		["Sravani", "Lakshmi", "Bhavani", "Swathi", "Mounika", "Harika", "Keerthi", "Sirisha", "Sowmya", "Divya", "Lavanya", "Pravallika", "Anusha", "Sindhu", "Navya"],
		["Reddy", "Naidu", "Rao", "Goud", "Yadav", "Varma", "Chowdary", "Babu", "Kumar", "Raju", "Prasad", "Murthy", "Sastry", "Teja", "Rathod"]],
	"ta": [["Karthik", "Senthil", "Murugan", "Vignesh", "Arun", "Prakash", "Saravanan", "Dinesh", "Gokul", "Bala", "Ashwin", "Hari", "Manikandan", "Surya", "Vetri"],
		["Priya", "Divya", "Kavitha", "Meena", "Lavanya", "Nandhini", "Sangeetha", "Revathi", "Deepa", "Gayathri", "Keerthana", "Abinaya", "Pavithra", "Sowmya", "Yamini"],
		["Kumar", "Raj", "Selvam", "Pandian", "Murugan", "Rajan", "Krishnan", "Subramani", "Velu", "Ganesan", "Ramasamy", "Natarajan", "Shankar", "Mani", "Durai"]],
	"bn": [["Arijit", "Sourav", "Subhajit", "Rakesh", "Debojit", "Sayan", "Abhijit", "Partha", "Tanmoy", "Biswajit", "Rohit", "Sandip", "Anirban", "Pritam", "Suman"],
		["Moumita", "Rimpa", "Tanushree", "Payel", "Sraboni", "Ankita", "Riya", "Mitali", "Susmita", "Puja", "Sharmistha", "Debolina", "Tania", "Rupa", "Soma"],
		["Das", "Ghosh", "Mondal", "Saha", "Roy", "Biswas", "Sarkar", "Pal", "Dey", "Halder", "Majumder", "Bose", "Mitra", "Naskar", "Mahato"]],
	"gu": [["Hardik", "Kishan", "Parth", "Jignesh", "Dhaval", "Nirav", "Bhavin", "Hiren", "Mehul", "Chirag", "Ketan", "Jay", "Ronak", "Vishal", "Mitesh"],
		["Hetal", "Krupa", "Dhara", "Nidhi", "Bhumi", "Mansi", "Riddhi", "Khushi", "Janvi", "Foram", "Payal", "Hiral", "Nisha", "Urvi", "Dhruvi"],
		["Patel", "Shah", "Desai", "Parmar", "Chauhan", "Solanki", "Rathod", "Vaghela", "Makwana", "Bhatt", "Joshi", "Trivedi", "Prajapati", "Thakor", "Vasava"]],
	"pa": [["Gurpreet", "Harpreet", "Manpreet", "Jaspreet", "Amandeep", "Karan", "Lovepreet", "Sukhwinder", "Navdeep", "Rajvir", "Simranjit", "Tejinder", "Arshdeep", "Gagandeep", "Jaskaran"],
		["Simran", "Harleen", "Navneet", "Jasleen", "Mandeep", "Prabhjot", "Kirandeep", "Rajwinder", "Amanpreet", "Ravneet", "Sukhpreet", "Gurleen", "Manjot", "Taranjit", "Komalpreet"],
		["Singh", "Kaur", "Gill", "Sandhu", "Dhillon", "Sidhu", "Brar", "Grewal", "Bains", "Mann", "Randhawa", "Virk", "Cheema", "Bajwa", "Aulakh"]],
	"as": [["Bikram", "Pranjal", "Dhruba", "Rituraj", "Hiranya", "Manash", "Bhaskar", "Partha", "Jyotish", "Nayan", "Dipankar", "Rupam", "Utpal", "Kaushik", "Mridul"],
		["Pinky", "Rashmi", "Bornali", "Jahnavi", "Dikshita", "Mousumi", "Chayanika", "Nilakshi", "Priyanka", "Bitopi", "Monalisa", "Junmoni", "Rupjyoti", "Dimpi", "Anamika"],
		["Bora", "Gogoi", "Saikia", "Baruah", "Kalita", "Deka", "Hazarika", "Phukan", "Das", "Nath", "Talukdar", "Sarma", "Medhi", "Borah", "Kakati"]],
	"hi": [["Rahul", "Amit", "Vikas", "Sunil", "Deepak", "Anuj", "Sachin", "Ravi", "Manish", "Ankit", "Sandeep", "Pankaj", "Rohit", "Gaurav", "Ajay"],
		["Pooja", "Neha", "Priya", "Sonam", "Kiran", "Anjali", "Ritu", "Shalini", "Komal", "Preeti", "Nisha", "Jyoti", "Kajal", "Mamta", "Suman"],
		["Sharma", "Verma", "Yadav", "Singh", "Kumar", "Chauhan", "Gupta", "Tiwari", "Mishra", "Pandey", "Rawat", "Saini", "Jat", "Meena", "Thakur"]],
	"np": [["Bikash", "Suman", "Ramesh", "Sanjay", "Prakash", "Dipesh", "Nabin", "Roshan", "Sujan", "Bibek", "Kiran", "Anil", "Sagar", "Rajan", "Bishal"],
		["Sarita", "Anita", "Sabina", "Puja", "Manisha", "Sunita", "Rojina", "Asmita", "Kabita", "Srijana", "Bimala", "Rachana", "Sushma", "Nirmala", "Pramila"],
		["Thapa", "Gurung", "Magar", "Rai", "Limbu", "Tamang", "Shrestha", "Karki", "Adhikari", "Bhandari", "Khadka", "Basnet", "Bohara", "Poudel", "Shahi"]],
	"lk": [["Kasun", "Nuwan", "Chamara", "Dilshan", "Tharindu", "Lahiru", "Isuru", "Sandun", "Ruwan", "Pradeep", "Chathura", "Asanka", "Janaka", "Supun", "Hasitha"],
		["Nadeesha", "Dilani", "Sachini", "Chamodi", "Nethmi", "Ishara", "Hiruni", "Tharushi", "Kaushalya", "Piumi", "Sewwandi", "Madushani", "Anjali", "Kavindi", "Dinithi"],
		["Perera", "Fernando", "Silva", "Jayasuriya", "Bandara", "Rathnayake", "Wijesinghe", "Herath", "Dissanayake", "Gunawardena", "Kumara", "Senanayake", "Wickramasinghe", "Rajapaksha", "Peiris"]],
	"bd": [["Rakib", "Sabbir", "Tanvir", "Mahmud", "Arif", "Shakil", "Rasel", "Nayeem", "Rifat", "Imran", "Sohel", "Jubayer", "Mehedi", "Sajib", "Fahim"],
		["Sumaiya", "Nusrat", "Sharmin", "Tania", "Mitu", "Shathi", "Jannat", "Rokeya", "Farzana", "Lima", "Sadia", "Afroza", "Mim", "Tasnim", "Rumana"],
		["Hossain", "Rahman", "Islam", "Ahmed", "Uddin", "Khan", "Sarker", "Mia", "Alam", "Chowdhury", "Akter", "Sheikh", "Molla", "Talukder", "Begum"]],
	"bt": [["Tashi", "Karma", "Sonam", "Pema", "Ugyen", "Kinley", "Dorji", "Jigme", "Tshering", "Sangay", "Kuenga", "Phuntsho", "Wangchuk", "Namgay", "Yeshi"],
		["Dechen", "Choki", "Pema", "Kinley", "Sonam", "Tashi", "Yangchen", "Deki", "Karma", "Tshering", "Dema", "Lhamo", "Wangmo", "Zangmo", "Chimi"],
		["Dorji", "Wangdi", "Tshering", "Penjor", "Lhendup", "Dema", "Norbu", "Gyeltshen", "Namgyel", "Rinzin", "Tenzin", "Choden", "Yangzom", "Lhamo", "Zangpo"]],
	"ir": [["Ali", "Reza", "Mohammad", "Hossein", "Amir", "Mehdi", "Saeed", "Hamid", "Javad", "Arash", "Kian", "Navid", "Omid", "Pouya", "Sina"],
		["Maryam", "Zahra", "Fatemeh", "Sara", "Niloufar", "Parisa", "Shirin", "Leila", "Mina", "Neda", "Roya", "Yasaman", "Elham", "Atena", "Setareh"],
		["Ahmadi", "Hosseini", "Karimi", "Rahimi", "Moradi", "Jafari", "Rezaei", "Sadeghi", "Ghasemi", "Mohammadi", "Kazemi", "Nouri", "Taheri", "Bagheri", "Hashemi"]],
	"za": [["Sipho", "Thabo", "Lwazi", "Kagiso", "Bongani", "Tebogo", "Mandla", "Neo", "Themba", "Jabu", "Luke", "Ruan", "Dylan", "Kyle", "Pieter"],
		["Nomsa", "Lerato", "Zanele", "Palesa", "Thandi", "Ayanda", "Naledi", "Busi", "Anele", "Mpho", "Megan", "Chloe", "Lisa", "Kayla", "Jade"],
		["Dlamini", "Nkosi", "Mokoena", "Khumalo", "Ndlovu", "Mahlangu", "Mthembu", "Sithole", "Naidoo", "Pillay", "van Wyk", "Botha", "Smit", "Jacobs", "Mabaso"]],
	"en": [["James", "Oliver", "Harry", "Jack", "Arjun", "Rohan", "Liam", "Ethan", "Kieran", "Sam", "Dev", "Nathan", "Ryan", "Tom", "Aaron"],
		["Emily", "Sophie", "Priya", "Chloe", "Grace", "Ella", "Anya", "Hannah", "Mia", "Jess", "Leah", "Zara", "Ruby", "Amy", "Nisha"],
		["Smith", "Patel", "Jones", "Brown", "Taylor", "Wilson", "Shah", "Evans", "Clarke", "Walker", "Hughes", "Gill", "Wright", "Mistry", "Bennett"]],
	"ke": [["Brian", "Kevin", "Dennis", "Collins", "Victor", "Kwame", "Emmanuel", "Isaac", "Joseph", "Samuel", "Moses", "Daniel", "Kofi", "Peter", "Felix"],
		["Faith", "Mercy", "Grace", "Esther", "Joy", "Sharon", "Akosua", "Agnes", "Ruth", "Purity", "Linda", "Gloria", "Ama", "Lydia", "Winnie"],
		["Otieno", "Kamau", "Mwangi", "Wanjiku", "Ochieng", "Mensah", "Nakato", "Okello", "Kiprop", "Mutua", "Asante", "Boateng", "Nsubuga", "Achieng", "Mugisha"]],
	"my": [["Amir", "Faiz", "Hafiz", "Irfan", "Danial", "Rizal", "Arif", "Syafiq", "Budi", "Dimas", "Rizky", "Ahmad", "Aiman", "Haziq", "Fikri"],
		["Aisyah", "Nurul", "Siti", "Farah", "Dewi", "Putri", "Ayu", "Intan", "Sari", "Nadia", "Amira", "Hani", "Rina", "Wulan", "Lestari"],
		["Rahman", "Ismail", "Hassan", "Abdullah", "Yusof", "Santoso", "Wijaya", "Saputra", "Hidayat", "Kurniawan", "Osman", "Salleh", "Pratama", "Setiawan", "Nugroho"]],
	"kr": [["Minjun", "Seojun", "Jihoon", "Hyunwoo", "Dohyun", "Jaewon", "Sungmin", "Taeyang", "Yejun", "Junho", "Ito", "Haruto", "Sota", "Ren", "Yuto"],
		["Seoyeon", "Jiwoo", "Minji", "Hayoon", "Soyeon", "Yuna", "Eunji", "Jisoo", "Hana", "Yui", "Sakura", "Aoi", "Mio", "Rin", "Hina"],
		["Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang", "Lim", "Han", "Oh", "Seo", "Shin", "Kwon"]],
	"jp": [["Haruto", "Sota", "Yuto", "Ren", "Riku", "Kaito", "Daiki", "Takumi", "Kenta", "Shota", "Hiroki", "Yuki", "Ryo", "Sho", "Kazuki"],
		["Yui", "Sakura", "Aoi", "Mio", "Rin", "Hina", "Nanami", "Haruka", "Misaki", "Ayaka", "Mai", "Saki", "Kana", "Riko", "Miyu"],
		["Sato", "Suzuki", "Takahashi", "Tanaka", "Ito", "Watanabe", "Yamamoto", "Nakamura", "Kobayashi", "Kato", "Yoshida", "Yamada", "Sasaki", "Matsumoto", "Inoue"]],
	"eu": [["Lukas", "Jan", "Max", "Tom", "Piotr", "Daan", "Jakub", "Finn", "Noah", "Kacper", "Leon", "Sem", "Mateusz", "Ruben", "Felix"],
		["Anna", "Emma", "Lena", "Zofia", "Sophie", "Julia", "Lotte", "Maja", "Mila", "Hanna", "Fenna", "Lea", "Natalia", "Sanne", "Laura"],
		["Müller", "de Vries", "Nowak", "Schmidt", "Jansen", "Kowalski", "Bakker", "Weber", "Wiśniewski", "Visser", "Fischer", "Smit", "Lewandowski", "Meyer", "Mulder"]],
	"sa": [["Mateo", "Santiago", "Lucas", "Gabriel", "Thiago", "Diego", "Joaquín", "Pedro", "Rafael", "Bruno", "Nicolás", "Felipe", "Tomás", "Matías", "Gustavo"],
		["Valentina", "Camila", "Sofía", "Isabela", "Lucía", "Mariana", "Julia", "Martina", "Ana", "Gabriela", "Daniela", "Beatriz", "Paula", "Florencia", "Larissa"],
		["Silva", "Santos", "González", "Rodríguez", "Oliveira", "Fernández", "Pereira", "López", "Souza", "Martínez", "García", "Costa", "Romero", "Quispe", "Flores"]],
}

## Combinations that are, or are too close to, real players' names (the names that headlined the 2025 world
## championship and the franchise league): never made.
const NAME_BLOCK := ["Pratik Waikar", "Ramji Kashyap", "Aditya Ganpule", "Priyanka Ingle", "Nasreen Shaikh", "Ashwini Shinde",
	"Akshay Bhangare", "Suyash Gargate", "Aniket Pote", "Sachin Bhargo", "Gautham MK", "Mehul Patel", "Rohan Shingade",
	"Sudam Gaikwad", "Vaishnavi Pawar", "Reshma Rathod", "Nirmala Bhati", "Meenu Rathod", "Chaitra B", "Sanjay Kumar"]

var _squads := {}


func is_club(id: String) -> bool:
	for c in CLUBS:
		if c[0] == id:
			return true
	return false


func club_ids() -> Array:
	var out := []
	for c in CLUBS:
		out.append(c[0])
	return out


## A side drawn as a shield (a state or a city side), not a flag.
func has_shield(id: String) -> bool:
	return is_state(id) or is_club(id)


func is_state(id: String) -> bool:
	for s in STATES:
		if s[0] == id:
			return true
	return false


func team(id: String) -> Dictionary:
	for n in NATIONS:
		if n[0] == id:
			return {"id": id, "key": n[1], "flag": n[2], "rating": [n[3], n[4]], "kit": n[5], "pool": n[6], "state": false}
	for s in STATES:
		if s[0] == id:
			return {"id": id, "key": s[1], "flag": "IND", "rating": [s[2], s[3]], "kit": s[4], "pool": s[5], "state": true}
	for c in CLUBS:
		if c[0] == id:
			return {"id": id, "key": c[1], "flag": "IND", "rating": [c[2], c[3]], "kit": c[4], "pool": c[5], "state": false, "club": true}
	return {"id": id, "key": id, "flag": "", "rating": [50, 50], "kit": ["888888", "333333", "ffffff"], "pool": "hi", "state": false}


func team_name(id: String) -> String:
	return tr(String(team(id).key))


## The team's invented nickname (states only: "Maharashtra Monsoon"), or "" for a country.
func team_nick(id: String) -> String:
	return tr("N_" + id) if is_state(id) else ""


func team_rating(id: String, women := false) -> int:
	return int((team(id).rating as Array)[1 if women else 0])


func nation_ids() -> Array:
	var out := []
	for n in NATIONS:
		out.append(n[0])
	return out


func state_ids() -> Array:
	var out := []
	for s in STATES:
		out.append(s[0])
	return out


func kit(id: String) -> Array:
	var k: Array = team(id).kit
	return [Color(k[0]), Color(k[1]), Color(k[2])]


func venue(id: String) -> Array:
	for v in VENUES:
		if v[0] == id:
			return v
	return VENUES[0]


func venue_ids() -> Array:
	var out := []
	for v in VENUES:
		out.append(v[0])
	return out


## The squad: 15 players (12 play in the classic game, 15 in the fast one), made from the team's id. Each has a number,
## a name, a role (a chaser who kills with dives, a runner who defends, or both) and ratings out of 100: speed
## (flat-out pace), turn (agility: how quickly he changes direction and how tight he takes the pole), reach (his
## dives), stamina, and read (his game sense: when to kho, where to run).
func squad(id: String, women := false) -> Array:
	var key := "%s|%s" % [id, women]
	if _squads.has(key):
		return _squads[key]
	var t := team(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var base := float((t.rating as Array)[1 if women else 0])
	var pool: Array = NAMES.get(String(t.pool), NAMES.hi)
	var givens: Array = pool[1 if women else 0]
	var families: Array = pool[2]
	var used := {}
	var out := []
	var roles := ["chaser", "chaser", "chaser", "chaser", "runner", "runner", "runner", "runner", "all", "all", "all", "all",
		"chaser", "runner", "all"]
	for i in 15:
		var nm := ""
		for tries in 40:
			var g: String = givens[rng.randi() % givens.size()]
			var f: String = families[rng.randi() % families.size()]
			if String(t.pool) == "pa" and f in ["Singh", "Kaur"]:
				f = "Kaur" if women else "Singh"
			nm = "%s %s" % [g, f]
			if not used.has(nm) and not (nm in NAME_BLOCK):
				break
		used[nm] = true
		var role: String = roles[i]
		var k := clampf(base + rng.randf_range(-9.0, 7.0) - (6.0 if i >= 12 else 0.0), 30.0, 99.0)
		var p := {
			"id": "%s%s%02d" % [id, "w" if women else "", i + 1],
			"num": i + 1,
			"name": nm,
			"role": role,
			"speed": roundi(clampf(k + rng.randf_range(-6, 8) + (3.0 if role == "runner" else 0.0), 25, 99)),
			"turn": roundi(clampf(k + rng.randf_range(-8, 8) + (4.0 if role == "runner" else 0.0), 25, 99)),
			"reach": roundi(clampf(k + rng.randf_range(-8, 8) + (6.0 if role == "chaser" else -4.0), 25, 99)),
			"stamina": roundi(clampf(k + rng.randf_range(-10, 8), 25, 99)),
			"read": roundi(clampf(k + rng.randf_range(-8, 8), 25, 99)),
			"skin": rng.randf(),
			"hair": rng.randi() % 4,
			"height": rng.randf_range(1.66, 1.84) - (0.1 if women else 0.0),
		}
		out.append(p)
	_squads[key] = out
	return out


## The best of the squad for a side of n: chasers and all-rounders for chasing, runners and all-rounders to defend.
func pick(id: String, women: bool, n: int, chasing: bool) -> Array:
	var sq: Array = squad(id, women).duplicate()
	sq.sort_custom(func(a, b): return _value(a, chasing) > _value(b, chasing))
	return sq.slice(0, n)


func _value(p: Dictionary, chasing: bool) -> float:
	if chasing:
		return p.speed * 0.35 + p.reach * 0.3 + p.read * 0.25 + p.turn * 0.1
	return p.turn * 0.35 + p.speed * 0.3 + p.read * 0.2 + p.stamina * 0.15
