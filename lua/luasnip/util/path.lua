local Path = {}

local uv = vim.loop

local sep = (function()
	if jit then
		local os = jit.os:lower()
		if vim.tbl_contains({ "linux", "osx", "bsd" }, os) then
			return "/"
		else
			return "\\"
		end
	end
	return package.config:sub(1, 1)
end)()

function Path.join(...)
	return table.concat({ ... }, sep)
end

function Path.exists(filepath)
	return uv.fs_stat(filepath) and true or false
end

function Path.async_read_file(path, callback)
	uv.fs_open(path, "r", tonumber("0666", 8), function(err, fd)
		assert(not err, err)
		uv.fs_fstat(fd, function(err, stat)
			assert(not err, err)
			uv.fs_read(fd, stat.size, 0, function(err, buffer)
				assert(not err, err)
				uv.fs_close(fd, function(err)
					assert(not err, err)
					callback(buffer)
				end)
			end)
		end)
	end)
end

---@param path string
---@return string buffer @content of file
function Path.read_file(path)
	local fd = assert(uv.fs_open(path, "r", tonumber("0666", 8)))
	local stat = assert(uv.fs_fstat(fd))
	local buf = assert(uv.fs_read(fd, stat.size, 0))
	uv.fs_close(fd)

	return buf
end

local MYCONFIG_ROOT = vim.env.MYVIMRC
-- if MYVIMRC is not set then it means nvim was called with -u
-- therefore the first script is the configuration
-- in case of calling -u NONE the plugin won't be loaded so we don't
-- have to handle that

if not MYCONFIG_ROOT then
	MYCONFIG_ROOT = vim.fn.execute("scriptnames"):match("1: ([^\n]+)")
end
-- remove the filename of the script  to optain where is it (most of the time it will be ~/.config/nvim/)

MYCONFIG_ROOT = MYCONFIG_ROOT:gsub(("%s[^%s]+$"):format(sep, sep), "")

function Path.expand(filepath)
	local expanded = filepath
		:gsub("^~", vim.env.HOME)
		:gsub("^[.]", MYCONFIG_ROOT)
	return uv.fs_realpath(expanded)
end

---Resolve a (chain of) symbolic link(s) to their final destination.
---@param path string
---@return string|nil
---Returns nil if the sym link points to an inexistent file.
---Assumes that path is a symlink, will return nil otherwise.
local function resolve_symlink(path)
	while true do
		local followed_path = uv.fs_readlink(path)
		if followed_path then
			local stat = uv.fs_stat(followed_path)
			if stat and stat.type ~= "link" then
				return followed_path, stat.type
			else
				path = followed_path
			end
		else
			return nil
		end
	end
end

---Return files and directories in path as a list
---@param root string
---@return string[] files, string[] directories
function Path.scandir(root)
	local files, dirs = {}, {}
	local fs = uv.fs_scandir(root)
	if fs then
		local name, type = "", ""
		while name do
			name, type = uv.fs_scandir_next(fs)
			local path = Path.join(root, name)
			if type == "file" then
				table.insert(files, path)
			elseif type == "directory" then
				table.insert(dirs, path)
			elseif type == "link" then
				local followed_path
				followed_path, type = resolve_symlink(path)
				if followed_path then
					if type == "file" then
						table.insert(files, followed_path)
					elseif type == "directory" then
						table.insert(dirs, followed_path)
					end
				end
			end
		end
	end
	return files, dirs
end

---Get basename
---@param filepath string
---@param ext boolean if true, separate the file extension
---@return string, string?
---Example:
---         Path.basename("~/.config/nvim/init.lua") -> init.lua
---         Path.basename("~/.config/nvim/init.lua", true) -> init, lua
function Path.basename(filepath, ext)
	local base = filepath
	if base:find(sep) then
		base = base:match(("%s([^%s]+)$"):format(sep, sep))
	end
	if ext then
		return base:match("(.*)%.(.+)")
	else
		return base
	end
end

return Path
