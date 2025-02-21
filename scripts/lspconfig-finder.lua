local function supported_servers()
	return vim.iter(vim.fs.dir(vim.api.nvim__get_runtime({ 'lua/lspconfig/configs' }, false, {})[1]))
		:map(function(fname) return string.gsub(fname, '.lua$', '') end)
end

local function splitLine(str)
	return string.gmatch(str, '[^\n]+')
end

local function main()
	local commands = supported_servers()
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
		local pkgJoined = table.concat(pkg, ',')
		outfile:write(server_name .. '=' .. pkgJoined .. '\n')
	end
	outfile:close()
end

main()
