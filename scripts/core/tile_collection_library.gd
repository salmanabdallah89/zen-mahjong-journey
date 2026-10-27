class_name TileCollectionLibrary
extends RefCounted
## Every tile collection found in the given folders, sorted for display.

const SHIPPED_DIR := "res://data/collections/"
const FALLBACK_ID := "classic"

var _collections: Array[TileCollection] = []
var _by_id := {}


static func discover(dirs: PackedStringArray = PackedStringArray([SHIPPED_DIR])) -> TileCollectionLibrary:
	var library := TileCollectionLibrary.new()
	for dir in dirs:
		library.add_dir(dir)
	return library


func add_dir(dir: String) -> void:
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for file: String in files:
		if file.ends_with(".json"):
			add(TileCollection.load_manifest(dir.path_join(file)))


func add(collection: TileCollection) -> void:
	if collection == null or collection.id.is_empty() or _by_id.has(collection.id):
		return
	_collections.append(collection)
	_by_id[collection.id] = collection
	_collections.sort_custom(func(a: TileCollection, b: TileCollection) -> bool:
		return a.order < b.order if a.order != b.order else a.id < b.id)


func all() -> Array[TileCollection]:
	return _collections


func get_collection(collection_id: String) -> TileCollection:
	return _by_id.get(collection_id)


func has(collection_id: String) -> bool:
	return _by_id.has(collection_id)
