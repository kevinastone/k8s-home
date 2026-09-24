package sabnzbd

#Misc: {
	dirscan_dir:                 string | *""
	dirscan_speed:               int | *5
	download_dir:                string | *"Downloads/incomplete"
	complete_dir:                string | *"Downloads/complete"
	complete_free:               #DataSize | *""
	auto_sort:                   string | *""
	enable_tv_sorting:           bool | *false
	tv_sort_string:              string | *""
	enable_movie_sorting:        bool | *false
	movie_sort_string:           string | *""
	enable_date_sorting:         bool | *false
	date_sort_string:            string | *""
	schedlines:                  string | *","
	direct_unpack:               bool | *false
	direct_unpack_tested:        bool | *false
	deobfuscate_final_filenames: bool | *true
	par_option:                  string | *""
	host_whitelist:              string | *""
	host_whitelist_inspection:   bool | *true
	api_key:                     string | *""
	nzb_key:                     string | *""
	no_dupes:                    bool | *false
	no_smart_dupes:              bool | *false
	notified_new_skin:           int | *0
	helpful_warnings:            bool | *true
	cache_limit:                 #DataSize | *""

	out: """
		[misc]
		dirscan_dir = \((#QuoteIni & {"in": dirscan_dir}).out)
		dirscan_speed = \(dirscan_speed)
		download_dir = \((#QuoteIni & {"in": download_dir}).out)
		complete_dir = \((#QuoteIni & {"in": complete_dir}).out)
		complete_free = \((#QuoteIni & {"in": complete_free}).out)
		auto_sort = \((#QuoteIni & {"in": auto_sort}).out)
		enable_tv_sorting = \(#BoolToInt["\(enable_tv_sorting)"])
		tv_sort_string = \((#QuoteIni & {"in": tv_sort_string}).out)
		enable_movie_sorting = \(#BoolToInt["\(enable_movie_sorting)"])
		movie_sort_string = \((#QuoteIni & {"in": movie_sort_string}).out)
		enable_date_sorting = \(#BoolToInt["\(enable_date_sorting)"])
		date_sort_string = \((#QuoteIni & {"in": date_sort_string}).out)
		schedlines = \(schedlines)
		direct_unpack = \(#BoolToInt["\(direct_unpack)"])
		direct_unpack_tested = \(#BoolToInt["\(direct_unpack_tested)"])
		deobfuscate_final_filenames = \(#BoolToInt["\(deobfuscate_final_filenames)"])
		par_option = \((#QuoteIni & {"in": par_option}).out)
		host_whitelist = \((#QuoteIni & {"in": host_whitelist}).out)
		host_whitelist_inspection = \(#BoolToInt["\(host_whitelist_inspection)"])
		api_key = \((#QuoteIni & {"in": api_key}).out)
		nzb_key = \((#QuoteIni & {"in": nzb_key}).out)
		no_dupes = \(#BoolToInt["\(no_dupes)"])
		no_smart_dupes = \(#BoolToInt["\(no_smart_dupes)"])
		notified_new_skin = \(notified_new_skin)
		helpful_warnings = \(#BoolToInt["\(helpful_warnings)"])
		cache_limit = \((#QuoteIni & {"in": cache_limit}).out)
		"""
}

misc: #Misc & {
	dirscan_dir:          "/incoming"
	download_dir:         "/downloads"
	complete_dir:         "/incoming"
	complete_free:        "1G"
	direct_unpack:        false
	direct_unpack_tested: true
	no_dupes:             true
	no_smart_dupes:       true
	notified_new_skin:    2
	helpful_warnings:     false
}
