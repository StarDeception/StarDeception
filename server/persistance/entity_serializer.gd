extends Node
class_name EntitySerializer

func serialize(data: Dictionary, base_key: String = "") -> Dictionary:
	var serializedData: Dictionary = {}
	
	for key in data.keys():
		if key == "children":
			continue
		var flatten_key = key if base_key == "" else base_key + key
		var value = data.get(key)
		
		if value is Vector3 or value is Dictionary:
			var subData = serialize(value, flatten_key + "_")
			for subKey in subData.keys():
				serializedData[subKey] = subData.get(subKey)
			#serializedData[key + "x"] = value.x
			#serializedData[key + "y"] = value.y
			#serializedData[key + "z"] = value.z
		else:
			serializedData[flatten_key] = value
	
	return serializedData
