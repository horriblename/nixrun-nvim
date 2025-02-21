local function supported_servers()
	return vim.iter(vim.fs.dir(vim.api.nvim__get_runtime({ 'lua/lspconfig/configs' }, false, {})[1]))
		:map(function(fname) return string.gsub(fname, '.lua$', '') end)
end

local function splitLine(str)
	return string.gmatch(str, '[^\n]+')
end

local function moduleExists(mod)
	return pcall(require, mod)
end

local binding_format = [[
return {
	package = "%s",
}
]]

local function main()
	local skipped = 0
	local no_pkg = 0
	local multi_pkgs = 0
	local single_pkg = 0
	local commands = supported_servers()
		:filter(function(server_name)
			-- filter out LSPs we already know
			local skip = moduleExists('nixrun.lsp.' .. server_name)
				or moduleExists('nixrun.overrides.' .. server_name)
			if skip then skipped = skipped + 1 end
			return not skip
		end)
		:map(function(server_name)
			local cmd = require('lspconfig.configs.' .. server_name).default_config.cmd
			if type(cmd) == 'table' then
				return cmd[1], server_name
			else
				-- godot lsp config uses vim.lsp.rpc.connect (returns a function) for some reason
				return nil
			end
		end)
		:map(function(cmd, server_name)
			local nix_locate = io.popen('nix-locate --whole-name --minimal bin/' .. cmd, 'r')
			if nix_locate then
				local pkgs = nix_locate:read('*a')
				nix_locate:close()
				return server_name, vim.iter(splitLine(pkgs)):totable()
			end
		end)

	local outfile = assert(io.open('gen.txt', 'w'))

	for server_name, pkg in commands do
		if #pkg == 1 then
			single_pkg = single_pkg + 1
			local f = assert(io.open('lua/nixrun/lsp/' .. server_name .. '.lua', 'w'))
			f:write(binding_format:format(pkg))
			f:close()
		elseif #pkg == 0 then
			no_pkg = no_pkg + 1
		else
			multi_pkgs = multi_pkgs + 1
		end
		local pkgJoined = table.concat(pkg, ',')
		outfile:write(server_name .. '=' .. pkgJoined .. '\n')
	end
	outfile:close()

	print("skipped: ", skipped, ", single: ", single_pkg, ", multi: ", multi_pkgs, ", none: ", no_pkg)
end

main()
