--require 'waterlua'

local params = {...}

local map = io.toAbsPath(params[1])
local lookupPaths = params[2]

if (lookupPaths ~= nil) then
	lookupPaths = lookupPaths:split(';')
end

lookupPaths = lookupPaths or {}

for i = 1, #lookupPaths, 1 do
	local path = lookupPaths[i]

	path = path:gsub('/', '\\')

	if not path:match('\\$') then
		path = path..'\\'
	end

	lookupPaths[i] = path
end

local inputDir = io.local_dir()..[[Input\]]
local outputDir = io.local_dir()..[[Output\]]

removeDir(inputDir)
removeDir(outputDir)

assert(map, 'no map')

osLib.clearScreen()

--io.local_require([[..\..\portLib]])

flushDir(inputDir)
createDir(inputDir)

mpqExtract(map, [[war3map.j]], inputDir)

flushDir(outputDir)
createDir(outputDir)

local fIn = io.open(inputDir..[[war3map.j]], 'r')
local fOut = io.open(outputDir..[[war3map.j]], 'w+')

local function splitargs(line)
	local res = {}

	while (line:len() > 0) do
		local pos, posEnd = line:find('[^%s]')

		if (pos == nil) then
			line = ""
		else
			line = line:sub(pos)

			local arg = nil

			if (line:sub(1, 1) == "\"") then
				line = line:sub(2)

				local pos, posEnd = line:find("\"")

				if (pos == nil) then
					pos = line:len() + 1
				end

				arg = line:sub(1, pos - 1)

				if (posEnd == nil) then
					line = ""
				else
					line = line:sub(posEnd + 1)
				end
			else
				local pos, posEnd = line:find('%s')

				if (pos == nil) then
					pos = line:len() + 1
				end

				arg = line:sub(1, pos - 1)

				if (posEnd == nil) then
					line = ""
				else
					line = line:sub(posEnd + 1)
				end
			end

			if (arg ~= nil) then
				res[#res + 1] = arg
			end
		end
	end

	return res
end

local function searchLine(line)
	local sear = '^%s*//! import%s+([%w%p_]*)'

	local name = line:match(sear)
--assert(false, line)
	if (name ~= nil) then
		--if ((name:sub(1, 1) == "\"") and (name:sub(name:len(), name:len()) == "\"")) then
		--	name = name:sub(2, name:len() - 1)
		--end
		name = splitargs(name)[1]

		local tryTable = {}

		local fImp = io.open(name, 'r')

		if not io.isAbsPath(name) then
			local i = 1

			while ((fImp == nil) and (i <= #lookupPaths)) do
				local path = lookupPaths[i]..name

				fImp = io.open(path, 'r')
				tryTable[#tryTable + 1] = path

				i = i + 1
			end
		end

		if (fImp == nil) then
			error('cannot open '..tostring(name)..' tried:\n'..table.concat(tryTable, '\n'))
		end

		if (fImp ~= nil) then
			fOut:write('//import start: ', name, '\n')

			for impLine in fImp:lines() do
				--fOut:write(impLine, '\n')
				searchLine(impLine)
			end

			fOut:write('//import end: ', name, '\n')

			fImp:close()
		else
			fOut:write('//import not found: ', name, '\n')

			error('import ', name, ' not found')
		end
	else
		fOut:write(line, '\n')
	end
end

for line in fIn:lines() do
	searchLine(line)
end

fIn:close()
fOut:close()

local impPort = createMpqPort()

impPort:addImport(outputDir..[[war3map.j]], [[war3map.j]])

impPort:commit(map)