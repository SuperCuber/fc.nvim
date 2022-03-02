local M = {};

function M.setup()
end

function M._check_fc()
    -- TODO: wait for vim to add better detection
    if string.match(vim.fn.argv(0), "bash%-fc") then
        M._shell = "bash"
        -- fix for git-bash on windows
        vim.api.nvim_set_option("shellcmdflag", "-c")
        M._setup_fc_environment()
    end
end

function M._setup_fc_environment()
    -- TODO: for testing, remove
    if M._shell == nil then
        M._shell = "bash"
    end

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
    vim.cmd ([[
        augroup FcNvimBuf
            au!
            au BufWritePost <buffer=]] .. M._editor_buf .. [[> lua require"fc"._editor_buf_written()
        augroup END
    ]])
end

function M._editor_buf_written()
    local command = vim.api.nvim_buf_get_lines(M._editor_buf, 0, vim.api.nvim_buf_line_count(M._editor_buf), true)
    local output = vim.fn.systemlist(M._shell, command)

    vim.api.nvim_buf_set_option(M._output_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(M._output_buf, 0, vim.api.nvim_buf_line_count(M._output_buf), true, output)
    vim.api.nvim_buf_set_option(M._output_buf, "modifiable", false)
end

return M
