vim.cmd [[
augroup FcNvim
    au!
    au VimEnter * lua require"fc"._check_fc()
augroup END

" For Dev
nnoremap ,fc :tabnew C:\Temp\fctest <bar> lua R("fc")._setup_fc_environment()<cr>
]]
