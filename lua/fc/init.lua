local M = {};

function M.setup()
end

-- TODO: unit testing, documentation

function M._check_fc()
    -- TODO: wait for vim to add better detection, and support more shell+os combos
    if string.match(vim.fn.argv(0), "bash%-fc") then
        -- This is required in environments like git-bash on windows since &shell will be cmd/powershell
        M._shell = { "bash", "-c" }
        M._setup_fc_environment()
    end
end

function M._setup_fc_environment()
    -- TODO: for testing, remove
    M._shell = { "bash", "-c" }

    -- Main editing window
    M._editor_win = vim.api.nvim_get_current_win()
    M._editor_buf = vim.api.nvim_win_get_buf(M._editor_win)

    -- Output preview window
    vim.cmd "vsplit"
    M._output_win = vim.api.nvim_get_current_win()
    M._output_buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(M._output_win, M._output_buf)
    vim.api.nvim_buf_set_option(M._output_buf, "modifiable", false)

    -- TODO: manpage/help window

    -- Editing loop
    vim.api.nvim_set_current_win(M._editor_win)
    -- this is a list of {command, output} from the last run
    M._last_command_state = {}
    vim.cmd ([[
        augroup FcNvimBuf
            au!
            au BufWritePost <buffer=]] .. M._editor_buf .. [[> lua require"fc"._editor_buf_written()
        augroup END
    ]])
end

local function cleanup_command(command)
    -- trim, remove trailing pipe
   return string.gsub(vim.trim(command), "%s*|$", "")
end

function M._editor_buf_written()
    local editor_contents = table.concat(vim.api.nvim_buf_get_lines(M._editor_buf, 0, -1, false), "\n")
    -- TODO: this doesn't behave like shells since my stdout and stderr are combined
    local command = vim.tbl_map(cleanup_command, vim.split(editor_contents, "|"))

    -- last save had more lines than current command, cut them off
    if #M._last_command_state > #command then
        for i=#command+1,#M._last_command_state do
            M._last_command_state[i] = nil
        end
    end

    -- keep output from unchanged lines
    -- by default we execute from past the commands (nothing changed so dont rerun)
    local execute_from_command = #command + 1
    for i, _ in ipairs(command) do
        if M._last_command_state[i] == nil or M._last_command_state[i].command ~= command[i] then
            execute_from_command = i
            break
        end
    end

    -- re-run changed lines
    for i=execute_from_command,#command do
        local shell_command = vim.deepcopy(M._shell)
        table.insert(shell_command, command[i])
        M._last_command_state[i] = {
            command = command[i],
            output = vim.fn.systemlist(shell_command, (M._last_command_state[i-1] or {}).output)
        }
        -- TODO: check for error status code and break
    end

    vim.api.nvim_buf_set_option(M._output_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(M._output_buf, 0, vim.api.nvim_buf_line_count(M._output_buf), true, M._last_command_state[#M._last_command_state].output)
    vim.api.nvim_buf_set_option(M._output_buf, "modifiable", false)
end

return M
