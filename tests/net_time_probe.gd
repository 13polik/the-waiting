extends SceneTree
## Manual check of the trusted-time source (needs internet):
##   godot --headless --path . --script res://tests/net_time_probe.gd
## Prints the network time, the device time and the difference.

const TimeClock := preload("res://scripts/core/time_clock.gd")
const URLS := ["https://www.apple.com/", "https://www.google.com/"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok := false
	for url in URLS:
		var http := HTTPRequest.new()
		http.timeout = 8.0
		root.add_child(http)
		if http.request(url, [], HTTPClient.METHOD_HEAD) != OK:
			print(url, ": request failed")
			continue
		var res: Array = await http.request_completed
		var net := -1.0
		for h in res[2]:
			if String(h).to_lower().begins_with("date:"):
				net = TimeClock.parse_http_date(String(h).substr(5).strip_edges())
		var wall := Time.get_unix_time_from_system()
		print("%s: result %d, http %d, network %.0f, device %.0f, difference %.0f s" % [url, res[0], res[1], net, wall, wall - net])
		ok = ok or net > 0.0
		http.queue_free()
	print("NET TIME OK" if ok else "NET TIME UNAVAILABLE")
	quit(0 if ok else 1)
