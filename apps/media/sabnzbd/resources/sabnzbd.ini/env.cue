package sabnzbd

#Env: {
	NZBGEEK_API_KEY:      string @tag(NZBGEEK_API_KEY)
	NEWSHOSTING_USERNAME: string @tag(NEWSHOSTING_USERNAME)
	NEWSHOSTING_PASSWORD: string @tag(NEWSHOSTING_PASSWORD)
}

#EnvKey: or([for k, _ in #Env {k}])
