package sabnzbd

#SslVerify: {
	#Value: "Disabled" | "Minimal" | "Medium" | "Strict"

	#ToInt: {
		"Disabled": 0
		"Minimal":  1
		"Medium":   2
		"Strict":   3
	}
}

#Server: {
	name:          string
	displayname:   string | *name
	host:          string | *name
	port:          int | *563
	ssl:           bool | *true
	ssl_verify:    #SslVerify.#Value | *"Strict"
	username_env?: #EnvKey
	password_env?: #EnvKey

	username: string
	password: string

	if username_env != _|_ {
		username: #Env[username_env]
	}
	if password_env != _|_ {
		password: #Env[password_env]
	}

	connections: int | *50
	enable:      bool | *true
	priority:    int | *0

	out: """
		[[\(name)]]
		name = \(name)
		displayname = \((#QuoteIni & {"in": displayname}).out)
		host = \(host)
		port = \(port)
		ssl = \(#BoolToInt["\(ssl)"])
		ssl_verify = \(#SslVerify.#ToInt[ssl_verify])
		username = \((#QuoteIni & {"in": username}).out)
		password = \((#QuoteIni & {"in": password}).out)
		connections = \(connections)
		enable = \(#BoolToInt["\(enable)"])
		priority = \(priority)
		"""
}

servers: [...#Server]
