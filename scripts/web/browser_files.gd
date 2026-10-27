class_name BrowserFiles
extends RefCounted
## Browser-owned picker/download. Only bounded bytes cross into the game.

var _callback: JavaScriptObject
var _pending: Callable


func pick(accept: String, limit: int, callback: Callable) -> bool:
	if not OS.has_feature("web") or _pending.is_valid():
		return false
	_pending = callback
	_callback = JavaScriptBridge.create_callback(_picked)
	var window := JavaScriptBridge.get_interface("window")
	window.gloamthreadFilePicked = _callback
	JavaScriptBridge.eval("""(() => {
	 const input = document.createElement('input'); input.type = 'file';
	 input.accept = %s;
	 input.addEventListener('cancel', () => window.gloamthreadFilePicked(JSON.stringify({cancelled:true})), {once:true});
	 input.onchange = () => {
	  const file = input.files && input.files[0];
	  if (!file) { window.gloamthreadFilePicked(JSON.stringify({cancelled:true})); return; }
	  if (file.size > %d) { window.gloamthreadFilePicked(JSON.stringify({error:'The selected file is too large.'})); return; }
	  const reader = new FileReader();
	  reader.onerror = () => window.gloamthreadFilePicked(JSON.stringify({error:'The selected file could not be read.'}));
	  reader.onload = () => window.gloamthreadFilePicked(JSON.stringify({name:file.name,data:String(reader.result).split(',')[1]}));
	  reader.readAsDataURL(file);
	 };
	 input.click();
	})()""" % [JSON.stringify(accept), limit], true)
	return true


func _picked(args: Array) -> void:
	if not _pending.is_valid():
		return
	var callback := _pending
	_pending = Callable()
	var value: Variant = JSON.parse_string(str(args[0])) if not args.is_empty() else null
	callback.call(value if value is Dictionary else {"error": "The selected file could not be read."})


func download(bytes: PackedByteArray, filename: String, mime: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, filename, mime)
