function _start_agent() {
	local agents
	local -a identities
	local -a options
	local _keychain_env_sh
	local _keychain_env_sh_gpg

	# load agents to start.
	zstyle -s :omz:plugins:keychain agents agents

	# load identities to manage.
	zstyle -a :omz:plugins:keychain identities identities

	# load additional options
	zstyle -a :omz:plugins:keychain options options

	# start keychain...
	keychain ${^options:-} --agents ${agents:-gpg} ${^identities}

	# Get the filenames to store/lookup the environment from
	_keychain_env_sh="$HOME/.keychain/$SHORT_HOST-sh"
	_keychain_env_sh_gpg="$HOME/.keychain/$SHORT_HOST-sh-gpg"

	# Source environment settings.
	[ -f "$_keychain_env_sh" ]     && . "$_keychain_env_sh"
	[ -f "$_keychain_env_sh_gpg" ] && . "$_keychain_env_sh_gpg"
}

_start_agent

# tidy up after ourselves
unfunction _start_agent
