local function supported_servers()
	return vim.iter(vim.api.nvim__get_runtime({ "lsp" }, true, {}))
		:map(function(path)
			return vim.iter(vim.fs.dir(path))
				:map(function(name, type)
					return type == "file" and name:match("(.*)%.lua$") or nil
				end)
				:totable()
		end)
		:flatten()
end

local function splitLine(str)
	return string.gmatch(str, "[^\n]+")
end

local function moduleExists(mod)
	return pcall(require, mod)
end

local binding_template = [[
return {
	package = "%s",
}
]]

---generates nixpkgs to lspconfig mappings based on command name
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
			local entry =
				assert(vim.lsp.config[server_name], "server " .. server_name .. " is missing from vim.lsp.config")
			local cmd = entry.cmd
			if type(cmd) == "table" then
				if cmd[1] == nil then
					print("skipped " .. server_name .. " due to empty array cmd")
					return nil
				end
				return cmd[1], server_name
			else
				-- godot lsp config uses vim.lsp.rpc.connect (returns a function) for some reason
				return nil
			end
		end)

	local outfile = assert(io.open('gen.txt', 'w'))

	for cmd, server_name in commands do
		local pkg
		local nix_locate = io.popen('nix-locate --whole-name --minimal bin/' .. cmd, 'r')
		if nix_locate then
			local pkgs = nix_locate:read('*a')
			nix_locate:close()
			pkg = vim.iter(splitLine(pkgs)):totable()
		end

		if pkg == nil then
		elseif #pkg == 1 then
			single_pkg = single_pkg + 1
			local f = assert(io.open('lua/nixrun/lsp/' .. server_name .. '.lua', 'w'))
			f:write(binding_template:format(pkg[1]))
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
