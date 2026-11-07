class_name WeatherState
extends RefCounted

const MODES:=["auto","clear","rain","mist","wind"]
const NAMES:={"auto":"Automático","clear":"Céu limpo","cloudy":"Nublado","rain":"Chuva","mist":"Neblina","wind":"Ventania"}
const PATTERN:=["clear","cloudy","rain","clear","mist","clear","rain","wind"]
static func sample(day:int,minute:float,mode:String="auto")->Dictionary:
	var kind:=mode
	if kind=="auto":kind=PATTERN[posmod(floori(minute/180)+(day-1)*3,8)]
	if not NAMES.has(kind):kind="clear"
	return {"kind":kind,"label":NAMES[kind],"rain":1.0 if kind=="rain" else 0.0,"cloud":0.68 if kind=="rain" else (0.4 if kind=="cloudy" else (0.2 if kind=="mist" else 0.0)),"mist":1.0 if kind=="mist" else (0.3 if kind=="rain" else 0.0),"wind":2.4 if kind=="wind" else (1.5 if kind=="rain" else 0.55)}
