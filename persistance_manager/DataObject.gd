class_name  DataObject

var position :Vector3
#var uuid: String
var uid: String
var name: String


func serialize():
	var dict = {

		"uid": uid,
		"name": name,
		#"uuid": uuid,
		"position":{
			"x": position.x,
			"y": position.y,
			"z": position.z
		}
	}
	return JSON.stringify(dict)


		#,
