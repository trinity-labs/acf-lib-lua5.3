--date and time functions 

module(..., package.seeall)

require("posix")
require("format")
require("fs")

--global for date formating see below for more information
--Mon Nov 26 19:56:10 UTC 2007 looks like most systems use this
--print(os.date(date.format))
formats = "%a %b %d %X %Z %Y"

months ={ {"January","Jan"},  
          {"February", "Feb"}, 
          {"March","Mar"}, 
          {"April", "Apr"},
	  {"May","May"},
	  {"June","Jun"},
	  {"July","Jul"},
	  {"August","Aug"},
	  {"September","Sep"},
	  {"October","Oct"},
	  {"November","Nov"},
	  {"December","Dec"}
	   }

revmonths = {["january"] = 1, ["jan"] = 1, 
	     ["february"] = 2, ["feb"] = 2,
	     ["march"] = 3, ["mar"] = 3, 
	     ["april"] = 4, ["apr"] = 4, 
	     ["may"] = 5,
	     ["june"] = 6, ["jun"] = 6,
	     ["july"] = 7, ["jul"] = 7,
	     ["august"] = 8, ["aug"] = 8,
	     ["september"] = 9, ["sep"] = 9,
	     ["october"] = 10, ["oct"] = 10,
	     ["november"] = 11, ["nov"] = 11,
	     ["december"] = 12, ["dec"] = 12 
	     }

dow = { {"Sunday","Sun"}, 
	{"Monday","Mon"},
	{"Tuesday","Tue"},
	{"Wednesday","Wed"},
	{"Thursday","Thu"},
	{"Friday","Fri"},
	{"Saturday","Sat"}
	}
	
revdow = { ["sunday"] = 1, ["sun"] = 2,
	   ["monday"] = 2, ["mon"] = 2,
	   ["tuesday"] = 3, ["tue"] = 3,
	   ["wednesday"] = 4, ["wed"] = 4,
	   ["thursday"] = 5, ["thu"] = 5,
	   ["friday"] = 6, ["fri"] = 6,
	   ["saturday"] = 7, ["sat"] =7
	   }

-- + usually denotes right of PM and - means left. It seems that /etc/TZ needs these 
--reversed for alpine/busybox. difference in col 2 and 5
--this list is not full. May need some more added. No Africa or Asia
--Abrr TZ,Real Offset, FullName, Location, What would be put in /etc/TZ(busybox needed offset)

timezones = {

{"A","+1","Alpha Time Zone","Military","Alpha-1"},
{"ACDT","+10:30","Australian Central Daylight Time","Australia","ACDT-10:30"},
{"ACST","+9:30","Australian Central Standard Time","Australia","ACST-9:30"},
{"ADT","-3","Atlantic Daylight Time","North America","ADT+3"},
{"AEDT","+11","Australian Eastern Daylight Time","Australia","AEDT-11"},
{"AEST","+10","Australian Eastern Standard Time","Australia","AEST-10"},
{"AKDT","-8","Alaska Daylight Time","North America","AKDT+8"},
{"AKST","-9","Alaska Standard Time","North America","AKST+9"},
{"AST","-4","Atlantic Standard Time","North America","AST+4"},
{"AWDT","+9","Australian Western Daylight Time","Australia","AWDT-9"},
{"AWST","+8","Australian Western Standard Time","Australia","AWST-8"},

{"B","+2","Bravo Time Zone","Military","Bravo-2"},
{"BST","+1","British Summer Time","Europe","BST-1"},

{"C","+3","Charlie Time Zone","Military","Charlie-3"},
{"CDT","-5","Central Daylight Time","North America","CDT+5"},
{"CEDT","+2","Central European Daylight Time","Europe","CEDT-2"},
{"CEST","+2","Central European Summer Time","Europe","CEST-2"},
{"CET","+1","Central European Time","Europe","CET-1"},
{"CST","+10:30","Central Summer(Daylight) Time","Australia","CST-10:30"},
{"CST","+9:30","Central Standard Time","Australia","CST-9:30"},
{"CST","-6","Central Standard Time","North America","CST+6"},
{"CXT","+7","Christmas Island Time","Australia","CXT-7"},

{"D","+4","Delta Time Zone","Military","Delta-4"},

{"E","+5","Echo Time Zone","Military","Echo-5"},
{"EDT","-4","Eastern Daylight Time","North America","EDT+4"},
{"EEDT","+3","Eastern European Daylight Time","Europe","EEDT-3"},
{"EEST","+3","Eastern European Summer Time","Europe","EEST-3"},
{"EET","+2","Eastern European Time","Europe","EET-2"},
{"EST","+11","Eastern Summer(Daylight) Time","Australia","EST-11"},
{"EST","+10","Eastern Standard Time","Australia","EST-10"},
{"EST","-5","Eastern Standard Time","North America","EST+5"},

{"F","+6","Foxtrot Time Zone","Military","Foxtrot-6"},

{"G","+7","Golf Time Zone","Military","Golf-7"},
{"GMT","+0","Greenwich Mean Time","Europe","GMT+0"},

{"H","+8","Hotel Time Zone","Military","Hotel-8"},
{"HAA","-3","Heure Avancée de l'Atlantique","North America","HAA+3"},
{"HAC","-5","Heure Avancée du Centre","North America","HAC+5"},
{"HADT","-9","Hawaii-Aleutian Daylight Time","North America","HADT+9"},
{"HAE","-4","Heure Avancée de l'Est","North America","HAE+4"},
{"HAP","-7","Heure Avancée du Pacifique","North America","HAP+7"},
{"HAR","-6","Heure Avancée des Rocheuses","North America","HAR+6"},
{"HAST","-10","Hawaii-Aleutian Standard Time","North America","HAST+10"},
{"HAT","-2:30","Heure Avancée de Terre-Neuve","North America","HAT+2:30"},
{"HAY","-8","Heure Avancée du Yukon","North America","HAY+8"},
{"HNA","-4","Heure Normale de l'Atlantique","North America","HNA+4"},
{"HNC","-6","Heure Normale du Centre","North America","HNC+6"},
{"HNE","-5","Heure Normale de l'Est","North America","HNE+5"},
{"HNP","-8","Heure Normale du Pacifique","North America","HNP+8"},
{"HNR","-7","Heure Normale des Rocheuses","North America","HNR+7"},
{"HNT","-3:30","Heure Normale de Terre-Neuve","North America","HNT+3:30"},
{"HNY","-9","Heure Normale du Yukon","North America","HNY+9"},

{"I","+9","India Time Zone","Military","India-9"},
{"IST","+1","Irish Summer Time","Europe","IST-1"},

{"K","+10","Kilo Time Zone","Military","Kilo-10"},

{"L","+11","Lima Time Zone","Military","Lima-11"},

{"M","+12","Mike Time Zone","Military","Mike-12"},
{"MDT","-6","Mountain Daylight Time","North America","MDT+6"},
{"MESZ","+2","Mitteleuroäische Sommerzeit","Europe","MESZ-2"},
{"MEZ","+1","Mitteleuropäische Zeit","Europe","MEZ-1"},
{"MST","-7","Mountain Standard Time","North America","MST+7"},

{"N","-1","November Time Zone","Military","November+1"},
{"NDT","-2:30","Newfoundland Daylight Time","North America","NDT+2:30"},
{"NFT","+11:30","Norfolk (Island) Time","Australia","NFT-11:30"},
{"NST","-3:30","Newfoundland Standard Time","North America","NST+3:30"},

{"O","-2","Oscar Time Zone","Military","Oscar+2"},

{"P","-3","Papa Time Zone","Military","Papa+3"},
{"PDT","-7","Pacific Daylight Time","North America","PDT+7"},
{"PST","-8","Pacific Standard Time","North America","PST+8"},

{"Q","-4","Quebec Time Zone","Military","Quebec+4"},

{"R","-5","Romeo Time Zone","Military","Romeo+5"},

{"S","-6","Sierra Time Zone","Military","Sierra+6"},

{"T","-7","Tango Time Zone","Military","Tango+7"},

{"U","-8","Uniform Time Zone","Military","Uniform+8"},
{"UTC","+0","Coordinated Universal Time","Europe","UTC+0"},

{"V","-9","Victor Time Zone","Military","Victor+9"},

{"W","-10","Whiskey Time Zone","Military","Whiskey+10"},
{"WEDT","+1","Western European Daylight Time","Europe","WEDT-1"},
{"WEST","+1","Western European Summer Time","Europe","WEST-1"},
{"WET","+0","Western European Time","Europe","WET+0"},
{"WST","+9","Western Summer(Daylight) Time","Australia","WST-9"},
{"WST","+8","Western Standard Time","Australia","WST-8"},

{"X","-11","X-ray Time Zone","Military","X-ray+11"},

{"Y","-12","Yankee Time Zone","Military","Yankee+12"},

{"Z","+0","Zulu Time Zone","Military","Zulu+0"}

}

--os.time() will give seconds since 1970-epoch
--os.date() will give formated time strings
--os.time{year=2007,month=1,day=1,hour=2,min=1,sec=1}
--os.date(date.format,os.time())

--give me a table
--t = { {year=2007,month=1,day=2,hour=2}, {year=2006,month=1,day=5} }
--will return a table sorted by oldest <-> newest 
--to grab the largest and smallest a,b=g[1],g[table.maxn(g)]
function date_to_seconds (t)
	g = {}
	count = table.maxn(t)
	for i = 1,count do
	g[#g+1] = os.time(t[i])
	end
	table.sort(g)
	return g
end

-- the reverse of date_to_seconds. expecting a table of seconds
--format can be changed. This seems to be standard, dow,mon,dom,time,zone,year
-- seems like %z- +0000 time zone format and %Z- 3 letter timezone undocumented or new

function seconds_to_date (t)
	g = {}
	count = table.maxn(t)
	for i = 1,count do
	g[#g+1] = os.date(formats,t[i])	
	end
	
	return g	
end

--Wed Nov 28 14:01:23 UTC 2007
--os.date(date.formats) put into a table
--year,month,day,hour,min,sec,isdst- may need a dst table to set this automatically
function string_to_table (str)
	if str == nil then str = os.date(formats) end
	g = {}
	temp = format.string_to_table(str,"%s")
	month = abr_month_num(temp[2])
	g["month"] = month
	day = temp[3]
	g["day"] = day
	--may do something with this if have a tz table ??
	tz = temp[5]
	year = temp[6]
	g["year"] = year
	temp2 = format.string_to_table(temp[4],":")
 	hour = temp2[1] 
 	g["hour"] = hour
 	min = temp2[2]
 	g["min"] = min
 	sec = temp2[3]
 	g["sec"] = sec
 	return g

end


--give dates in seconds and gives the difference in years,months,days,...
--gives a table back with hour,min,month,sec,day,year to display something like
--you have 10 years, 14 hours, 10 days to renew you certificate
-- in secs - year,  day, hour,min,sec
t_time = { field_names = {"years","days","hours","minutes","seconds"},
	                   31556926,86400,3600,60,1
	                   }

function date_diff (d1, d2)
	g = {}	
	if d2 == nil then d2 = os.time() end 
	--first sum of seconds
	sum = math.abs(os.difftime(d1,d2))
	--going to go through and get it smaller with each pass through the table
	for a,b in ipairs(t_time) do
	print(sum)
	hold = math.modf(sum/b)
	g[t_time.field_names[a]] = hold
	sum = (sum - (hold*b))
	end
	
	return g
end

--give a search number and return the month name

function num_month_name (search)
	return months[search][1]
end

--give a search number and return the month abr

function num_month_name_abr (search)
	return months[search][2]
end

function name_month_num (search)
	return revmonths[string.lower(search)]
end

function abr_month_num (search)
	return revmonths[string.lower(search)]
end

function num_dow_name (search)
	return dow[search][1]
end

function num_dow_name_abr (search)
	return dow[search][2]
end

function name_dow_num (search)
	return revdow[string.lower(search)]
end

function abr_dow_num (search)
	return revdow[string.lower(search)]
end

--tell me what TimeZone my system is set to

function what_tz ()
	f = fs.read_file_as_array("/etc/TZ") or {}
	local tz = f[1]
	return tz
end

--change the timezone my system is set to

function change_tz ( tz )
	--give us something like CET-1, this is busy box offset need to fix.
	
	tz = string.gsub(tz, "%+", "%%+")
	tz = string.gsub(tz, "%-", "%%-")
	tz = "^" .. tz .. "$"
	result = {}
	for a=1,table.maxn(date.timezones) do
	c = string.match(date.timezones[a][5], tz)
	if c ~= nil then result[#result +1] = c end
	end
	
	if table.maxn(result) == 1 then 
	fs.write_file("/etc/TZ", result[1])
	mess = "Success"
	else
	mess = "Too many matches."
	end
		
	return mess,date.what_tz()
end
