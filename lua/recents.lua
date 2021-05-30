local api = vim.api
local buf
local recents = {}
local ns = api.nvim_create_namespace("recents")
local pos_after_art
local has_fzf
local last_path = ""
local in_wsl = nil
local data_path = nil
local cache_path = nil
local recents_storage = nil
--local recents_storage = vim.fn.stdpath("cache").."/recents.txt"

local art = [[
888b    888                            d8b
8888b   888                            Y8P
88888b  888
888Y88b 888  .d88b.   .d88b.  888  888 888 88888b.d88b.
888 Y88b888 d8P  Y8b d88""88b 888  888 888 888 "888 "88b
888  Y88888 88888888 888  888 Y88  88P 888 888  888  888
888   Y8888 Y8b.     Y88..88P  Y8bd8P  888 888  888  888
888    Y888  "Y8888   "Y88P"    Y88P   888 888  888  888

out of the box
]]
art = "recents.nvim - Slick recents navigaton"

function table.find(table, element)
  for k, value in pairs(table) do
    if value == element then
      return k
    end
  end
  return -1
end

local function center_with_len(str, len)
  local width = api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(len / 2)
  return string.rep(' ', shift) .. str
end

local function get_shift(len)
  local width = api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(len / 2)
  return shift
end

--[[
function string:split(delimiter)
  local result = {}
  local from  = 1
  local delim_from, delim_to = string.find(self, delimiter, from)
  while delim_from do
    table.insert(result, string.sub(self, from, delim_from-1))
    from = delim_to + 1
    delim_from, delim_to = string.find(self, delimiter, from)
  end
  table.insert(result, string.sub(self, from))
  return result
end
]]--

local function center_lines(s)
  local maxlen = 0
  -- for some reason this works better than any lua solution, why
  local lines = vim.fn.split(s, "\n")
  for k, line in ipairs(lines) do
    local l = string.len(line)
    if l > maxlen then
      maxlen = l
    end
  end
  local out = {}
  for k, line in ipairs(lines) do
    table.insert(out, center_with_len(line, maxlen))
  end
  return out
end

local function push_down(lines, amt)
  local out = {}
  for i = 1, amt do
    table.insert(out, "")
  end
  for k, line in ipairs(lines) do
    table.insert(out, line)
  end
  return out
end

local function setup_buffer()
  local height = api.nvim_win_get_height(0)
  buf = api.nvim_create_buf(false, true)

  api.nvim_win_set_buf(0, buf)
  api.nvim_buf_set_name(buf, "Recents")
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(buf, "filetype", "recents")

  --api.nvim_buf_set_lines(buf, 0, -1, false, center_lines(art))
  local lines = push_down(center_lines(art), math.floor(height / 4))
  table.insert(lines, "")
  pos_after_art = #lines
  if has_fzf then
    table.insert(lines, center_with_len("[r] Search recents with FZF", 80))
  end
  local homedir = vim.fn.expand("$HOME")
  for k, recent in ipairs(recents) do
    local recent2 = string.gsub(recent, homedir, "~")
    table.insert(lines, center_with_len("["..k.."] "..recent2, 80))
  end
  if not has_fzf and #recents < 1 then
    -- keeps cursor movement consistent
    table.insert(lines, get_shift(80).."  ")
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    end_line = pos_after_art - 1,
    hl_group = "String"
  })
  for i = pos_after_art + 1, #lines do
    local line = lines[i]
    local b1, _ = string.find(line, "%[")
    local b2, _ = string.find(line, "%]")
    api.nvim_buf_set_extmark(buf, ns, i - 1, b1 - 1, {
      end_line = i - 1,
      end_col = b2,
      hl_group = "Keyword"
    })
  end

  api.nvim_buf_set_option(buf, "modifiable", false)
  --api.nvim_buf_set_option(buf, "cursorline", true)
  api.nvim_win_set_cursor(0, {pos_after_art + 1, get_shift(80)})
end

local function move_cursor_down()
  local pos = api.nvim_win_get_cursor(0)
  local new_row = math.max(pos[1] - 1, pos_after_art + 1)
  api.nvim_win_set_cursor(0, {new_row, get_shift(80)})
end

local function set_mappings()
  local mappings = {
    --['['] = 'update_view(-1)',
    --[']'] = 'update_view(1)',
    --['<cr>'] = 'open_file()',
    --h = 'update_view(-1)',
    --l = 'update_view(1)',
    --q = 'close_window()',
    k = 'move_cursor_down()'
  }

  for k,v in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"recents".'..v..'<cr>', {
        nowait = true, noremap = true, silent = true
      })
  end
  local other_chars = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'l', 'm', 'n', 'o', 'p', 'q', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
  }
  if not has_fzf then
    table.insert(other_chars, 'r')
  else
    api.nvim_buf_set_keymap(buf, 'n', 'r', ':lua require"recents".do_fzf()<CR>', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', 'R', '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', '<c-R>', '', { nowait = true, noremap = true, silent = true })
  end
  for k,v in ipairs(other_chars) do
    api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
  end
  for k, _ in ipairs(recents) do
    api.nvim_buf_set_keymap(buf, 'n', tostring(k), ':lua require"recents".handle_number('..k..')<CR>', { nowait = true, noremap = true, silent = true })
  end
  api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':lua require"recents".select_()<CR>', { nowait = true, noremap = true, silent = true})
end

local function get_wsl()
  if in_wsl ~= nil then
    return
  end
  if vim.fn.has("unix") == 1 then
    vim.fn.system("which wsl.exe")
    in_wsl = vim.v.shell_error == 0
    --[[if in_wsl then
      print("In wsl!")
    end]]--
  else
    in_wsl = false
  end
end

function string.trim(str)
  if str == '' then
    return str
  else
    local startPos = 1
    local endPos   = #str

    while (startPos < endPos and str:byte(startPos) <= 32) do
      startPos = startPos + 1
    end

    if startPos >= endPos then
      return ''
    else
      while (endPos > 0 and str:byte(endPos) <= 32) do
        endPos = endPos - 1
      end

      return str:sub(startPos, endPos)
    end
  end
end

local function setup_cache_path()
  if cache_path ~= nil then
    return
  end
  get_wsl()
  if in_wsl then
    local wpath = vim.fn.system({
      "nvim.exe",
      "--headless",
      "-c",
      "echo stdpath('cache')",
      "-c",
      "qa!",
    })
    local lpath = string.trim(vim.fn.system({
      "wslpath",
      "-u",
      wpath,
    }))
    cache_path = lpath
    recents_storage = lpath.."/recents.txt"
  else
    cache_path = vim.fn.stdpath("cache")
    recents_storage = vim.fn.stdpath("cache").."/recents.txt"
  end
  if in_wsl then
    local wpath = vim.fn.system({
      "nvim.exe",
      "--headless",
      "-c",
      "echo stdpath('data')",
      "-c",
      "qa!",
    })
    local lpath = string.trim(vim.fn.system({
      "wslpath",
      "-u",
      wpath,
    }))
    cache_path = lpath
    recents_storage = lpath.."/recents.txt"
  else
    cache_path = vim.fn.stdpath("data")
    recents_storage = vim.fn.stdpath("data").."/recents.txt"
  end
end

local function setup_recents_path()
  if recents_storage ~= nil then
    return
  end
  setup_cache_path()
  recents_storage = data_path.."/recents.txt"
end

local function read_recents()
  get_wsl()
  setup_recents_path()
  if vim.fn.filereadable(recents_storage) == 0 then
    return
  end
  recents = vim.fn.readfile(recents_storage)
end

local function recents_setup()
  has_fzf = vim.fn.exists("*fzf#run")
  read_recents()
  setup_buffer()
  set_mappings()
end

local function write_recents()
  vim.fn.writefile(recents, recents_storage)
end

local function dir_changed()
  read_recents()
  local dir = vim.fn.getcwd()

  if last_path ~= dir then
    last_path = dir
    local i = table.find(recents, dir)
    if i ~= -1 then
      table.remove(recents, i)
    end
    table.insert(recents, 1, dir)
    write_recents()
  end
end

local function handle_dir(path)
  get_wsl()
  setup_cache_path()
  if in_wsl and string.find(path, "^/") == nil then
    print("Written ", path, " to ", cache_path.."/recents_win_path.txt")
    vim.fn.writefile({path}, cache_path.."/recents_win_path.txt")
    vim.fn.jobstart("wsl.exe neovide.exe", {detach = true})
    api.nvim_command("qa")
    return
    -- in WSL, need to convert windows path
    --path2 = string.trim(vim.fn.system({
    --  "wslpath",
    --  "-u",
    --  path,
    --}))
  elseif not in_wsl and string.find(path, "^/") ~= nil then
    -- FIXME: work with vanilla nvim setups
    vim.fn.writefile({path}, cache_path.."/recents_wsl_path.txt")
    local ppid = string.trim(vim.fn.system("(gwmi win32_process | ? processid -eq (gwmi win32_process | ? processid -eq  $PID).parentprocessid).parentprocessid"))
    vim.fn.writefile({ppid}, cache_path.."/recents_win_pid.txt")
    vim.fn.jobstart({"cmd", "/C", "start", "/b", "", "neovide", "--wsl"}, {detach = true})
    --vim.fn.chanclose(j, "stdin")
    api.nvim_command("qa")
    return
    -- in Windows, need to convert WSL path
    --path2 = string.trim(vim.fn.system({
    --  "wslpath",
    --  "-w",
    --  path,
    --}))
  end
  api.nvim_command("cd "..path)
  api.nvim_command("bw")
  if vim.fn.exists(":NERDTree") == 2 then
    api.nvim_command("NERDTree")
  end
end

local function handle_number(n)
  handle_dir(recents[n])
end

local function do_fzf()
  if not has_fzf then
    return
  end
  if #recents < 1 then
    print("No recents to FZF!")
    return
  end

  vim.fn["fzf#run"]{
    source = recents,
    sink = handle_dir
  }
end

local function select_()
  local pos = api.nvim_win_get_cursor(0)
  local row = pos[1]
  if row <= pos_after_art then
    return
  end
  local row2 = row - pos_after_art
  if has_fzf and row2 < 2 then
    do_fzf()
  else
    handle_number(row2 - 1)
  end
end

local function edit_recents()
  setup_recents_path()
  api.nvim_command("e "..recents_storage)
end

local function load_from_file()
  setup_cache_path()
  get_wsl()
  local path
  if in_wsl then
    local p2 = vim.fn.glob(cache_path.."/recents_win_pid.txt")
    --print("pid path=", p2)
    if vim.fn.filereadable(p2) == 1 then
      local ppid = string.trim(vim.fn.readfile(p2)[1])
      --print("parent pid=", ppid)
      vim.fn.system({"taskkill.exe", "/pid", tostring(ppid), "/f"})
      vim.fn.delete(p2)
    end
    path = vim.fn.glob(cache_path.."/recents_wsl_path.txt")
  else
    path = vim.fn.glob(cache_path.."/recents_win_path.txt")
  end
  local dir = string.trim(vim.fn.readfile(path)[1])
  if dir ~= "" then
    vim.fn.delete(path)
    handle_dir(dir)
  end
end

local function set_art(s)
  art = s
end

return {
  recents = recents_setup,
  edit_recents = edit_recents,
  dir_changed = dir_changed,
  move_cursor_down = move_cursor_down,
  do_fzf = do_fzf,
  handle_number = handle_number,
  load_from_file = load_from_file,
  set_art = set_art,
  select_ = select_,
}
