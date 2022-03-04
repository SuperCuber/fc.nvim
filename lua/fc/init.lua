local M = {};

function M.setup()
end

-- TODO: (?) add a way to force re-run on a command
-- TODO: unit testing
-- TODO: configuration, documentation

function M._check_fc()
    -- TODO: wait for vim to add better detection, and support more shell+os combos
    if string.match(vim.fn.argv(0), "bash%-fc") then
        -- This is required in environments like git-bash on windows since &shell will be cmd/powershell
        M._shell = { "bash", "-c" }
        M._setup_fc_environment()
    elseif string.match(vim.fn.argv(0), "zsh") then
        M._shell = { "zsh", "-c" }
        M._setup_fc_environment()
    end
end

function M._setup_fc_environment()
    -- Main editing window
    M._editor_win = vim.api.nvim_get_current_win()
    M._editor_buf = vim.api.nvim_win_get_buf(M._editor_win)

    -- Output preview window
    vim.cmd "vsplit"
    M._output_win = vim.api.nvim_get_current_win()
    M._output_buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(M._output_win, M._output_buf)
    vim.api.nvim_buf_set_option(M._output_buf, "modifiable", false)

    vim.api.nvim_set_current_win(M._editor_win)
    vim.cmd "split"
    M._help_win = vim.api.nvim_get_current_win()
    M._help_buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(M._help_win, M._help_buf)
    vim.api.nvim_buf_set_option(M._help_buf, "modifiable", false)

    vim.api.nvim_set_current_win(M._editor_win)
    -- this is a list of {command, output} from the last run
    M._last_command_state = {}
    -- Save -> re-run
    vim.cmd ([[
        augroup FcNvimBuf
            au!
            au BufWritePost <buffer=]] .. M._editor_buf .. [[> lua require"fc"._editor_buf_written()
        augroup END
    ]])
    -- Get help
    vim.api.nvim_buf_set_keymap(M._editor_buf, 'n', 'K', [[:lua require"fc"._command_help()<cr>]], { noremap = true, silent = true })
end

local function cleanup_command(command)
    -- trim, remove trailing pipe
   return string.gsub(vim.trim(command), "%s*|$", "")
end

function M._make_shell_command(command)
    local cmd = vim.deepcopy(M._shell)
    table.insert(cmd, command)
    return cmd
end

function M._editor_buf_written()
    local editor_contents = table.concat(vim.api.nvim_buf_get_lines(M._editor_buf, 0, -1, false), "\n")
    -- TODO: this doesn't behave like shells since my stdout and stderr are combined
    local command = vim.tbl_map(cleanup_command, vim.split(editor_contents, "|"))

    local new_command_state = {}

    -- keep output from unchanged lines
    for i, _ in ipairs(command) do
        if M._last_command_state[i] ~= nil and M._last_command_state[i].command == command[i] then
            table.insert(new_command_state, M._last_command_state[i])
        else
            break
        end
    end

    -- run changed lines
    local last_command = new_command_state[#new_command_state]
    for i=#new_command_state+1,#command do
        last_command = {
            command = command[i],
            output = vim.fn.systemlist(
                M._make_shell_command(command[i]),
                (new_command_state[i-1] or {}).output
            )
        }
        if vim.v.shell_error == 0 then
            table.insert(new_command_state, last_command)
        else
            table.insert(last_command.output, "")
            table.insert(last_command.output, "[command failed with status " .. vim.v.shell_error .. "]")
            -- don't insert into new_command_state since it failed
            break
        end
    end

    vim.api.nvim_buf_set_option(M._output_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(M._output_buf, 0, vim.api.nvim_buf_line_count(M._output_buf), true, last_command.output)
    vim.api.nvim_buf_set_option(M._output_buf, "modifiable", false)

    M._last_command_state = new_command_state
end

function M._command_help()
    local cmd = vim.fn.expand("<cword>", false, false)
    local helptext = vim.fn.systemlist(M._make_shell_command("man " .. cmd), nil)
    if vim.v.shell_error ~= 0 then
        helptext = vim.fn.systemlist(M._make_shell_command(cmd .. " --help"), nil)
    end

    vim.api.nvim_buf_set_option(M._help_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(M._help_buf, 0, vim.api.nvim_buf_line_count(M._help_buf), true, helptext)
    vim.api.nvim_buf_set_option(M._help_buf, "modifiable", false)
end

return M
